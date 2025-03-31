#!/bin/sh

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

TELEMETRY_PORT=3334

# Update here in case of any change on the docker-compose.yml file
HOST=http://localhost
PORT=3333
VOLUME_NAME="autodroid_worker_data"
DOCKER_NETWORK_NAME="autodroid_network"
DOCKER_API_SERVICE_NAME="autodroid_api"
#

API_IMAGE_NAME="malwaredatalab/autodroid-api"
WORKER_IMAGE_NAME="malwaredatalab/autodroid-worker"
TOOL_IMAGE_NAME="malwaredatalab/malsyngen"
CONTAINER_NAME_PREFIX="autodroid_worker"
WATCHER_SERVER_IMAGE_NAME="malwaredatalab/autodroid-watcher-server"
WATCHER_SERVER_CONTAINER_NAME="autodroid_watcher_server"
WATCHER_CLIENT_IMAGE_NAME="malwaredatalab/autodroid-watcher-client"
WATCHER_CLIENT_INSTANCE_NAME="autodroid_watcher_local_client"
WATCHER_CLIENT_PM2_SERVICE_NAME="autodroid-watcher"
DEFAULT_NUM_WORKERS=1
DEFAULT_EXPECTED_WORKERS=1

DATASET_FILE_PATH="./docs/samples/dataset_example.csv"

clear

show_help() {
  echo "Usage: $0 [-k FIREBASEKEY] [-u USERNAME] [-p PASSWORD] [-n NUM_WORKERS] [-e EXPECTED_WORKERS] [-w EXPECTED_WATCHERS]"
  echo
  echo "Options:"
  echo "  -k, --firebasekey FIREBASEKEY   Firebase API key"
  echo "  -u, --username USERNAME         Firebase username (email)"
  echo "  -p, --password PASSWORD         Firebase password"
  echo "  -n, --num-workers NUM_WORKERS   Number of worker containers to start locally (default: 1)"
  echo "  -e, --expected-workers NUM      Total number of workers expected (local + remote) (default: 1)"
  echo "  -w, --expected-watchers NUM     Number of watchers expected (default: 1)"
  echo "  -h, --help                      Show this help message"
}

dropVolumeData() {
  if [ -d "./.runtime" ]; then
    echo "[INFO] Removing ./.runtime directory..." >&2
    docker run --rm -v "$(pwd)":/workdir busybox rm -rf /workdir/.runtime
  fi

  if [ -d "./autodroid-watcher-client" ]; then
    echo "[INFO] Removing ./autodroid-watcher-client directory..." >&2
    rm -rf ./autodroid-watcher-client
  fi
}

cleanup() {
  echo "[INFO] Starting cleanup process..."
  docker-compose down -v

  if [ "$(docker ps -q -f name="$WATCHER_SERVER_CONTAINER_NAME")" ]; then
    echo "[INFO] Stopping watcher server..." >&2
    if ! docker stop "$WATCHER_SERVER_CONTAINER_NAME" >/dev/null 2>&1; then
      echo "[WARNING] Failed to stop watcher server container" >&2
    fi
  fi

  if [ "$(docker ps -aq -f name="$WATCHER_SERVER_CONTAINER_NAME")" ]; then
    echo "[INFO] Removing watcher server container..." >&2
    if ! docker rm -f "$WATCHER_SERVER_CONTAINER_NAME" >/dev/null 2>&1; then
      echo "[WARNING] Failed to remove watcher server container" >&2
    fi
  fi

  # Stop and remove worker containers
  docker ps -aq -f name="$CONTAINER_NAME_PREFIX" | while read -r container_id; do
    echo "[INFO] Removing container $container_id..." >&2
    if ! docker rm -f "$container_id" >/dev/null 2>&1; then
      echo "[WARNING] Failed to remove container $container_id" >&2
    fi
  done

  PM2_SERVICE_EXISTS=$(pm2 jlist 2>/dev/null | jq -e ".[] | select(.name == \"$WATCHER_CLIENT_PM2_SERVICE_NAME\")" 2>/dev/null)
  PM2_EXIT_STATUS=$?
  
  if [ "$PM2_EXIT_STATUS" -eq 0 ]; then
    echo "[INFO] Found watcher client service, stopping it..." >&2
    if ! pm2 stop "$WATCHER_CLIENT_PM2_SERVICE_NAME" >/dev/null 2>&1; then
      echo "[WARNING] Failed to stop watcher client service" >&2
    fi
    if ! pm2 delete "$WATCHER_CLIENT_PM2_SERVICE_NAME" >/dev/null 2>&1; then
      echo "[WARNING] Failed to delete watcher client service" >&2
    fi
  fi

  if [ "$(docker volume ls -q -f name="$VOLUME_NAME")" ]; then
    echo "[INFO] Removing existing $VOLUME_NAME volume..." >&2
    if ! docker volume rm "$VOLUME_NAME" >/dev/null 2>&1; then
      echo "[WARNING] Failed to remove volume $VOLUME_NAME" >&2
    fi
  fi

  dropVolumeData
}

stop() {
  echo "[INFO] Stopping the demo..." >&2
  cleanup

  if [ $# -gt 0 ]; then
    greeting "$@"
  fi
  exit 0
}

exit_on_error() {
  echo "[ERROR] $1" >&2
  cleanup
  wait
  exit 1
}

greeting() {
  echo "__________________________________________________________________\n"
  cat << 'EOF'
                 __               __                       __
                /\ \__           /\ \               __    /\ \
   __     __  __\ \ ,_\   ___    \_\ \  _ __   ___ /\_\   \_\ \
 /'__`\  /\ \/\ \\ \ \/  / __`\  /'_` \/\`'__\/ __`\/\ \  /'_` \
/\ \L\.\_\ \ \_\ \\ \ \_/\ \L\ \/\ \L\ \ \ \//\ \L\ \ \ \/\ \L\ \
\ \__/.\_\\ \____/ \ \__\ \____/\ \___,_\ \_\\ \____/\ \_\ \___,_\
 \/__/\/_/ \/___/   \/__/\/___/  \/__,_ /\/_/ \/___/  \/_/\/__,_ /
EOF
  echo "\n__________________________________________________________________\n"
  if [ $# -gt 0 ]; then
    for param in "$@"; do
      echo "$param"
    done
    echo "__________________________________________________________________"
  fi

}

step() {
  echo "__________________________________________________________________\n"
  for param in "$@"; do
    echo "$param"
  done
  echo "__________________________________________________________________\n"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -k|--firebasekey)
      FIREBASEKEY="$2"
      shift 2
      ;;
    -u|--username)
      USERNAME="$2"
      shift 2
      ;;
    -p|--password)
      PASSWORD="$2"
      shift 2
      ;;
    -n|--num-workers)
      NUM_WORKERS="$2"
      shift 2
      ;;
    -e|--expected-workers)
      EXPECTED_WORKERS="$2"
      shift 2
      ;;
    -w|--expected-watchers)
      EXPECTED_WATCHERS="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "[ERROR] Invalid option: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

if [ -z "$NUM_WORKERS" ]; then
  NUM_WORKERS=$DEFAULT_NUM_WORKERS
fi

if [ -z "$EXPECTED_WORKERS" ]; then
  EXPECTED_WORKERS=$DEFAULT_EXPECTED_WORKERS
fi

if [ -z "$EXPECTED_WATCHERS" ]; then
  EXPECTED_WATCHERS=1
fi

if ! echo "$NUM_WORKERS" | grep -qE '^[0-9]+$' || [ "$NUM_WORKERS" -lt 0 ]; then
  exit_on_error "Number of workers must be a non-negative integer"
fi

if ! echo "$EXPECTED_WORKERS" | grep -qE '^[0-9]+$' || [ "$EXPECTED_WORKERS" -lt 1 ]; then
  exit_on_error "Expected number of workers must be a positive integer"
fi

if ! echo "$EXPECTED_WATCHERS" | grep -qE '^[0-9]+$' || [ "$EXPECTED_WATCHERS" -lt 1 ]; then
  exit_on_error "Expected number of watchers must be a positive integer"
fi

if [ "$EXPECTED_WORKERS" -lt "$NUM_WORKERS" ]; then
  exit_on_error "Expected number of workers cannot be less than the number of local workers"
fi

firebase_login() {
  FIREBASE_LOGIN_RESPONSE=$(curl -s -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$FIREBASEKEY" \
    -H "Content-Type: application/json" \
    -d '{
      "email": "'"$USERNAME"'",
      "password": "'"$PASSWORD"'",
      "returnSecureToken": true
    }')

  ID_TOKEN=$(echo "$FIREBASE_LOGIN_RESPONSE" | jq -r .idToken)
  REFRESH_TOKEN=$(echo "$FIREBASE_LOGIN_RESPONSE" | jq -r .refreshToken)

  if [ "$ID_TOKEN" = "null" ] || [ -z "$ID_TOKEN" ] || [ "$REFRESH_TOKEN" = "null" ] || [ -z "$REFRESH_TOKEN" ] ; then
    exit_on_error "Please check your Firebase credentials."
    return
  fi

  ID_TOKEN_EXP=$(echo "$ID_TOKEN" | cut -d "." -f2 | base64 -d 2>/dev/null | jq -r .exp)

  if [ "$ID_TOKEN_EXP" = "null" ] || [ -z "$ID_TOKEN_EXP" ];
  then
    exit_on_error "Failed to calculate Firebase token expiration date."
    return
  fi

  echo "[INFO] Logged into Firebase." >&2
}

exchange_refresh_to_id_token() {
  if [ -z "$REFRESH_TOKEN" ]; then
    exit_on_error "Refresh token is not set."
  fi

  echo "[INFO] Refreshing Firebase token..." >&2

  NEW_TOKEN_RESPONSE=$(curl -s -X POST "https://securetoken.googleapis.com/v1/token?key=$FIREBASEKEY" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN")

  echo "[INFO] Refreshing Firebase token... $NEW_TOKEN_RESPONSE" >&2

  NEW_ID_TOKEN=$(echo "$NEW_TOKEN_RESPONSE" | jq -r .idToken)

   if [ "$NEW_ID_TOKEN" = "null" ]; then
    exit_on_error "Failed to refresh Firebase token."
  fi

  NEW_EXP=$(echo "$NEW_ID_TOKEN" | cut -d "." -f2 | base64 -d 2>/dev/null | jq -r .exp)

  if [ "$ID_TOKEN_EXP" = "null" ] || [ -z "$ID_TOKEN_EXP" ];
  then
    exit_on_error "Failed to calculate Firebase token expiration date."
    return
  fi

  ID_TOKEN="$NEW_ID_TOKEN"
  ID_TOKEN_EXP="$NEW_EXP"

  echo "[INFO] Firebase token refreshed." >&2
}

is_token_expiring_soon() {
  CURRENT_TIME=`date +%s`
  TIME_LEFT=`expr $ID_TOKEN_EXP - $CURRENT_TIME`

  if [ $TIME_LEFT -lt 300 ]; then
    return 0
  else
    return 1
  fi
}

refresh_and_get_token() {
  if is_token_expiring_soon; then
    exchange_refresh_to_id_token
  fi

  echo "$ID_TOKEN"
}

if ! command -v docker >/dev/null 2>&1; then
  exit_on_error "Docker is not installed. Please install Docker."
fi

if ! docker info >/dev/null 2>&1; then
  exit_on_error "Current user cannot run Docker commands."
fi

if ! command -v node >/dev/null 2>&1; then
  exit_on_error "Node is not installed. Please install Node (https://nodejs.org/en/download/), use fnm or nvm to install it (recommended)."
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[INFO] jq is not installed. Installing..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y jq
  elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y jq
  elif command -v apk >/dev/null 2>&1; then
    sudo apk add --no-cache jq
  else
    exit_on_error "Could not install jq. Please install it manually."
  fi
fi

DOCKER_VERSION=$(docker version -f "{{.Server.Version}}")
DOCKER_VERSION_MAJOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 1)
DOCKER_VERSION_MINOR=$(echo "$DOCKER_VERSION"| cut -d'.' -f 2)
DOCKER_VERSION_BUILD=$(echo "$DOCKER_VERSION"| cut -d'.' -f 3)

if [ "${DOCKER_VERSION_MAJOR}" -lt 26 ]; then
  echo "Docker version should be 26.0.0 or higher. Got $DOCKER_VERSION"
  exit 1
fi

if [ ! -f "./docker-compose.yml" ]; then
  exit_on_error "docker-compose.yml not found in the current directory."
fi

if ! grep -q "^ *${DOCKER_API_SERVICE_NAME}:" docker-compose.yml; then
  exit_on_error "$DOCKER_API_SERVICE_NAME service not found in docker-compose.yml."
fi

REQUIRED_ENV_VARS="
FIREBASE_AUTHENTICATION_PROVIDER_PROJECT_ID
FIREBASE_AUTHENTICATION_PROVIDER_CLIENT_EMAIL
FIREBASE_AUTHENTICATION_PROVIDER_PRIVATE_KEY
GOOGLE_STORAGE_PROVIDER_PROJECT_ID
GOOGLE_STORAGE_PROVIDER_CLIENT_EMAIL
GOOGLE_STORAGE_PROVIDER_PRIVATE_KEY
GOOGLE_STORAGE_PROVIDER_BUCKET_NAME
ADMIN_EMAILS
"

get_env_var() {
  VAR_NAME=$1
  VALUE=$(docker-compose config | awk -v var="$VAR_NAME" '$1 == var":"{gsub(/"/, "", $2); print $2}')

  if [ -z "$VALUE" ] || [ "$VALUE" = "null" ] || [ "$VALUE" = "" ]; then
    exit_on_error "$VAR_NAME is missing or empty in $DOCKER_API_SERVICE_NAME environment variables."
  fi

  echo "$VALUE"
}

check_env_var() {
  VAR_NAME=$1
  VALUE=$(get_env_var "$VAR_NAME")

  if [ $? -ne 0 ]; then
    exit 1  # Exit the script if get_env_var failed
  fi
}

for VAR in $REQUIRED_ENV_VARS; do
  check_env_var "$VAR"
done

ADMIN_EMAILS=$(get_env_var "ADMIN_EMAILS")

check_if_admin() {
  if echo "$ADMIN_EMAILS" | grep -q "$USERNAME"; then
    return 0
  else
    return 1
  fi
}

greeting

if [ ! -f "$DATASET_FILE_PATH" ]; then
  exit_on_error "File $DATASET_FILE_PATH not found."
fi

FILE_SIZE=$(stat -c%s "$DATASET_FILE_PATH")
FILE_MD5=$(md5sum "$DATASET_FILE_PATH" | awk '{ print $1 }')
MIME_TYPE=$(file --mime-type -b "$DATASET_FILE_PATH")

while [ -z "$FIREBASEKEY" ] || [ ${#FIREBASEKEY} -lt 10 ]; do
  echo "Enter Firebase API KEY (find it inside your Firebase Project Settings → General → Your Apps → Select App → apiKey value):"
  read FIREBASEKEY
  if [ -z "$FIREBASEKEY" ] || [ ${#FIREBASEKEY} -lt 10 ]; then
    echo "[ERROR] Firebase API KEY must be at least 10 characters long. Please enter a valid key."
  fi
done

while [ -z "$USERNAME" ] || ! check_if_admin || ! echo "$USERNAME" | grep -E -q '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; do
  echo "Enter Firebase email:"
  read USERNAME
  if [ -z "$USERNAME" ] || ! echo "$USERNAME" | grep -E -q '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
    echo "[ERROR] Please enter a valid email address."
  fi

  if ! check_if_admin; then
    echo "[ERROR] $USERNAME is not an admin. Please enter an admin email like $ADMIN_EMAILS. (Set this on docker_compose.yml file)"
  fi
done

while [ -z "$PASSWORD" ] || [ ${#PASSWORD} -le 1 ] || [ -z "$ID_TOKEN"]; do

  while [ -z "$PASSWORD" ] || [ ${#PASSWORD} -le 1 ]; do
    stty -echo
    echo "Enter Firebase Password:"
    read PASSWORD
    stty echo

    if [ -z "$PASSWORD" ] || [ ${#PASSWORD} -le 1 ]; then
      echo "[ERROR] Password must be more than 1 character long. Please enter a valid password."
      continue
    fi
  done

  firebase_login

  if [ -n "$ID_TOKEN" ]; then
    break
  else
    echo "[ERROR] Wrong password or login failed."
    PASSWORD=""
  fi
done

echo "[INFO] Pulling tool image $TOOL_IMAGE_NAME:latest..."
docker pull "$TOOL_IMAGE_NAME:latest"
echo "[INFO] Tool image pulled successfully."

TELEMETRY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
echo "[INFO] Generated telemetry token: $TELEMETRY_TOKEN"

trap 'stop' 0
trap 'stop' INT

set -e

echo "[INFO] Press Ctrl+C to stop the demo."

docker-compose down
dropVolumeData
docker-compose pull
docker-compose up -d

until [ "$(curl -s -o /dev/null -w ''%{http_code}'' $HOST:$PORT/health/readiness)" -eq 200 ]; do
  echo "[INFO] Waiting for backend to be ready..."
  sleep 5
done
echo "[INFO] Backend is ready."

call_backend() {
  local CALL_BACKEND_METHOD="$1"
  local CALL_BACKEND_ENDPOINT="$HOST:$PORT$2"
  local CALL_BACKEND_TOKEN="$(refresh_and_get_token)"
  local CALL_BACKEND_BODY="$3"

  RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -X $CALL_BACKEND_METHOD -H "Authorization: Bearer $CALL_BACKEND_TOKEN" -H "Content-Type: application/json" -d "$CALL_BACKEND_BODY" $CALL_BACKEND_ENDPOINT)

  RESPONSE_BODY=$(echo "$RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
  RESPONSE_HTTP_STATUS=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

  if ! echo "$RESPONSE_HTTP_STATUS" | grep -qE '^[0-9]+$'; then
    echo "ERROR RESPONSE: " "$RESPONSE_BODY" >&2
    exit_on_error "Invalid HTTP status: $RESPONSE_HTTP_STATUS"
  elif [ "$RESPONSE_HTTP_STATUS" -lt 200 ] || [ "$RESPONSE_HTTP_STATUS" -ge 300 ]; then
    echo "ERROR RESPONSE: " "$RESPONSE_BODY" >&2
    exit_on_error "Backend returned HTTP status $RESPONSE_HTTP_STATUS."
  elif echo "$RESPONSE_BODY" | jq . >/dev/null 2>&1; then
    echo "$RESPONSE_BODY"
  else
    exit_on_error "Failed to parse JSON response."
  fi
}

check_workers_available() {
  local WORKERS_RESPONSE=$(call_backend "GET" "/admin/worker")
  local WORKERS_WITH_LAST_SEEN=$(echo "$WORKERS_RESPONSE" | jq -r '.edges[] | select(.node.last_seen_at != null) | .node.id' | wc -l)
  
  if [ "$WORKERS_WITH_LAST_SEEN" -eq 0 ]; then
    echo "[INFO] No workers detected yet..."
    return 1
  fi
  
  if [ "$WORKERS_WITH_LAST_SEEN" -lt "$EXPECTED_WORKERS" ]; then
    echo "[INFO] Waiting for workers to be active... (Active workers: $WORKERS_WITH_LAST_SEEN/$EXPECTED_WORKERS)"
    return 1
  fi

  echo "[INFO] All workers are available and active."
  return 0
}

#
# STEP 1
#
step "Step 1" "Create a processor - getting the processor_id to request processing."
PROCESSOR_CREATE_RESPONSE=$(call_backend "POST" "/admin/processor" "{
            \"name\": \"MalSynGen\",
            \"version\": \"0.0.1\",
            \"image_tag\": \"$TOOL_IMAGE_NAME:latest\",
            \"description\": \"Expande datasets de malware\",
            \"tags\": \"MalSynGen,Latest\",
            \"allowed_mime_types\": \"text/csv\",
            \"visibility\": \"PUBLIC\",
            \"configuration\": {
                \"output_result_file_glob_patterns\": [\"datasets/*\"],
                \"output_metrics_file_glob_patterns\": [\"metrics/**/*\"],
                \"dataset_input_argument\": \"input_dataset\",
                \"dataset_input_value\": \"/MalSynGen/shared/inputs\",
                \"dataset_output_argument\": \"output_dir\",
                \"dataset_output_value\": \"/MalSynGen/shared/outputs\",
                \"command\": \"/MalSynGen/shared/app_run.sh\",
                \"parameters\": [
                    {
                        \"sequence\": 1, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"RandomForest,SupportVectorMachine,DecisionTree,AdaBoost,Perceptron,SGDRegressor,XGboost\",
                        \"name\": \"classifier\", \"description\": \"Classificador (ou lista de classificadores separada por ,)\"
                    },
                    {
                        \"sequence\": 2, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"float32\",
                        \"name\": \"data_type\", \"description\": \"Tipo de dado para representar as características das amostras.\"
                    },
                    {
                        \"sequence\": 3, \"type\": \"INTEGER\", \"is_required\": true, \"default_value\": \"2000\",
                        \"name\": \"num_samples_class_malware\", \"description\": \"Número de amostras da Classe 1 (maligno).\"
                    },
                    {
                        \"sequence\": 4, \"type\": \"INTEGER\", \"is_required\": true, \"default_value\": \"2000\",
                        \"name\": \"num_samples_class_benign\", \"description\": \"Número de amostras da Classe 0 (benigno).\"
                    },
                    {
                        \"sequence\": 5, \"type\": \"INTEGER\", \"is_required\": false, \"default_value\": \"100\",
                        \"name\": \"number_epochs\", \"description\": \"Número de épocas (iterações de treinamento).\"
                    },
                    {
                        \"sequence\": 6, \"type\": \"INTEGER\", \"is_required\": false, \"default_value\": \"5\",
                        \"name\": \"k_fold\", \"description\": \"Número de folds para validação cruzada.\"
                    },
                    {
                        \"sequence\": 7, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"0.0\",
                        \"name\": \"initializer_mean\", \"description\": \"Valor central da distribuição gaussiana do inicializador.\"
                    },
                    {
                        \"sequence\": 8, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"0.5\",
                        \"name\": \"initializer_deviation\", \"description\": \"Desvio padrão da distribuição gaussiana do inicializador.\"
                    },
                    {
                        \"sequence\": 9, \"type\": \"INTEGER\", \"is_required\": false, \"default_value\": \"128\",
                        \"name\": \"latent_dimension\", \"description\": \"Dimensão do espaço latente para treinamento cGAN.\"
                    },
                    {
                        \"sequence\": 10, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"Adam\",
                        \"name\": \"training_algorithm\", \"description\": \"Algoritmo de treinamento para cGAN ('Adam', 'RMSprop', 'Adadelta').\"
                    },
                    {
                        \"sequence\": 11, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"LeakyReLU\",
                        \"name\": \"activation_function\", \"description\": \"Função de ativação da cGAN ('LeakyReLU', 'ReLU', 'PReLU').\"
                    },
                    {
                        \"sequence\": 12, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"0.2\",
                        \"name\": \"dropout_decay_rate_g\", \"description\": \"Taxa de decaimento do dropout do gerador da cGAN.\"
                    },
                    {
                        \"sequence\": 13, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"0.4\",
                        \"name\": \"dropout_decay_rate_d\", \"description\": \"Taxa de decaimento do dropout do discriminador da cGAN.\"
                    },
                    {
                        \"sequence\": 14, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"512\",
                        \"name\": \"dense_layer_sizes_g\", \"description\": \"Valor das camadas densas do gerador (um ou mais valores separados por ,).\"
                    },
                    {
                        \"sequence\": 15, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"512\",
                        \"name\": \"dense_layer_sizes_d\", \"description\": \"Valor das camadas densas do discriminador (um ou mais valores separados por ,).\"
                    },
                    {
                        \"sequence\": 16, \"type\": \"INTEGER\", \"is_required\": false, \"default_value\": \"32\",
                        \"name\": \"batch_size\", \"description\": \"Tamanho do lote da cGAN.\"
                    },
                    {
                        \"sequence\": 17, \"type\": \"INTEGER\", \"is_required\": false, \"default_value\": \"20\",
                        \"name\": \"verbosity\", \"description\": \"Nível de verbosidade.\"
                    },
                    {
                        \"sequence\": 18, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"0.0\",
                        \"name\": \"latent_mean_distribution\", \"description\": \"Média da distribuição do ruído aleatório de entrada.\"
                    },
                    {
                        \"sequence\": 19, \"type\": \"STRING\", \"is_required\": false, \"default_value\": \"1.0\",
                        \"name\": \"latent_stander_deviation\", \"description\": \"Desvio padrão do ruído aleatório de entrada.\"
                    }
                ]
            }
        }")
PROCESSOR_ID=$(echo "$PROCESSOR_CREATE_RESPONSE" | jq -r .id)
if [ -z "$PROCESSOR_ID" ] || [ "$PROCESSOR_ID" = "null" ]; then
  exit_on_error "Failed to create processor. Processor ID is missing."
fi
echo "Processor ID: $PROCESSOR_ID"


#
# STEP 2
#
step "Step 2" "Create a registration token to register a worker."
WORKER_REGISTRATION_TOKEN=$(call_backend "POST" "/admin/worker/registration-token" "{
  \"is_unlimited_usage\": true
}" | jq -r .token)
if [ -z "$WORKER_REGISTRATION_TOKEN" ] || [ "$WORKER_REGISTRATION_TOKEN" = "null" ]; then
  exit_on_error "Failed to create worker registration token."
fi
echo "Worker Registration Token: $WORKER_REGISTRATION_TOKEN"
echo
echo "[INFO] If you want to start a worker on a remote server, follow these steps:"
echo
echo "1. Install the watcher client:"
echo "curl -s https://raw.githubusercontent.com/MalwareDataLab/autodroid-watcher-client/main/install.sh | bash -s -- \\"
echo "  --token \"$TELEMETRY_TOKEN\" \\"
echo "  --url \"<<TELEMETRY_URL>>\" \\"
echo "  --name \"telemetry-client-X\" \\"
echo
echo "Note: Replace <<TELEMETRY_URL>> with:"
echo "- Local network: http://<ip>:$TELEMETRY_PORT (port $TELEMETRY_PORT)"
echo "- ngrok: https://<your-ngrok-url>.ngrok.io (tunnel to port $TELEMETRY_PORT)"
echo "- cloudflared: https://<your-cloudflared-url> (tunnel to port $TELEMETRY_PORT)"
echo
echo "2. Start the worker:"
echo "docker run --rm --network host \\"
echo "  -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "  -v autodroid_worker_data:/usr/app/temp:rw \\"
echo "  --pull always $WORKER_IMAGE_NAME \\"
echo "  -u \"<<BACKEND_URL>>\" \\"
echo "  -n \"autodroid-worker-X\" \\"
echo "  -t \"$WORKER_REGISTRATION_TOKEN\""
echo
echo "Note: Replace <<BACKEND_URL>> with:"
echo "- Local network: http://<ip>:$PORT (port $PORT)"
echo "- ngrok: https://<your-ngrok-url>.ngrok.io (tunnel to port $PORT)"
echo "- cloudflared: https://<your-cloudflared-url> (tunnel to port $PORT)"
echo
echo "Replace X with the worker number (e.g., autodroid-worker-1, autodroid-worker-2)"
echo "Create /usr/app/temp on the target machine before running"
echo
echo "[INFO] The script will start $NUM_WORKERS worker(s) locally. And will wait for $EXPECTED_WORKERS workers (local + remote) to be available."
echo
echo
echo "Press Enter to continue after starting all workers (local and remote)..."
read dummy


#
# STEP 3
#
step "Step 3" "Start $NUM_WORKERS worker container(s)."
if [ "$NUM_WORKERS" -gt 0 ]; then
  echo "[INFO] Pulling worker image $WORKER_IMAGE_NAME..."
  docker pull "$WORKER_IMAGE_NAME"
  echo "[INFO] Worker image pulled successfully."

  echo "[INFO] Installing watcher client for local workers..."
  curl -s https://raw.githubusercontent.com/MalwareDataLab/autodroid-watcher-client/main/install.sh | bash -s -- \
    --token "$TELEMETRY_TOKEN" \
    --url "http://localhost:$TELEMETRY_PORT" \
    --service "$WATCHER_CLIENT_PM2_SERVICE_NAME" \
    --name "$WATCHER_CLIENT_INSTANCE_NAME"
  echo "[INFO] Watcher client installed for local workers."

  for i in $(seq 1 "$NUM_WORKERS"); do
    CONTAINER_NAME="${CONTAINER_NAME_PREFIX}${i}"
    
    docker run --name "$CONTAINER_NAME" --rm --network host \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v "$VOLUME_NAME":/usr/app/temp:rw \
      --pull always "$WORKER_IMAGE_NAME" \
      -u "http://host.docker.internal:$PORT" \
      -n "autodroid-worker${i}" \
      -t "$WORKER_REGISTRATION_TOKEN" &
    
    echo "Worker container $CONTAINER_NAME started."
  done

  while ! check_workers_available; do
    sleep 5
  done
else
  echo "[INFO] No local workers will be started."
  echo "[INFO] Waiting for at least one remote worker to be available..."
  while ! check_workers_available; do
    sleep 5
  done
fi

#
# STEP 4
#
step "Step 4" "Create a dataset - getting the upload_url to send it."
echo "Dataset Information" "Size: $FILE_SIZE bytes" "MD5 Hash: $FILE_MD5" "MIME Type: $MIME_TYPE"
DATASET_CREATE_RESPONSE=$(call_backend "POST" "/dataset" "{
  \"description\": \"Test dataset Drebin\",
  \"tags\": \"test,remove\",
  \"filename\": \"dataset_example.csv\",
  \"md5_hash\": \"$FILE_MD5\",
  \"size\": $FILE_SIZE,
  \"mime_type\": \"$MIME_TYPE\"
}")
DATASET_ID=$(echo "$DATASET_CREATE_RESPONSE" | jq -r .id)
UPLOAD_URL=$(echo "$DATASET_CREATE_RESPONSE" | jq -r .file.upload_url)

if [ -z "$DATASET_ID" ] || [ "$DATASET_ID" = "null" ]; then
  exit_on_error "Failed to create dataset. Dataset ID is missing."
fi

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" = "null" ]; then
  exit_on_error "Failed to create dataset. Upload URL is missing."
fi

echo "Dataset ID: $DATASET_ID"

#
# STEP 5
#
step "Step 5" "Upload the dataset to the storage provider."
UPLOAD_RESPONSE=$(curl -s -w "HTTPSTATUS:%{http_code}" -X PUT -H "Content-Type: $MIME_TYPE" --data-binary @"$DATASET_FILE_PATH" "$UPLOAD_URL")
UPLOAD_RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
UPLOAD_HTTP_STATUS=$(echo "$UPLOAD_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

if ! echo "$UPLOAD_HTTP_STATUS" | grep -qE '^[0-9]+$'; then
  echo "ERROR RESPONSE: " "$UPLOAD_RESPONSE" >&2
  exit_on_error "Invalid HTTP status: $UPLOAD_HTTP_STATUS"
elif [ "$UPLOAD_HTTP_STATUS" -ne 200 ]; then
  echo "ERROR RESPONSE: " "$UPLOAD_RESPONSE" >&2
  exit_on_error "Failed to upload dataset. HTTP status $UPLOAD_HTTP_STATUS."
else
  echo "[INFO] Dataset uploaded successfully."
  
  DATASET_URL_RESPONSE=$(call_backend "GET" "/dataset/$DATASET_ID")
  DATASET_PUBLIC_URL=$(echo "$DATASET_URL_RESPONSE" | jq -r .file.public_url)
  if [ -z "$DATASET_PUBLIC_URL" ] || [ "$DATASET_PUBLIC_URL" = "null" ]; then
    echo "[WARNING] Could not get dataset public URL."
  fi
fi

#
# STEP 6
#
step "Step 6" "Request processing for the dataset(s) using the telemetry server. Waiting for all processing to finish."
docker pull "$WATCHER_SERVER_IMAGE_NAME"
docker run --name "$WATCHER_SERVER_CONTAINER_NAME" --rm \
  --network="$DOCKER_NETWORK_NAME" \
  -p "$TELEMETRY_PORT:$TELEMETRY_PORT" \
  -v "$SCRIPT_DIR/experiments:/app/experiments" \
  --pull always "$WATCHER_SERVER_IMAGE_NAME" \
  -p "$TELEMETRY_PORT" \
  -e prod \
  -i 1 \
  -q "$EXPECTED_WATCHERS" \
  -t "$TELEMETRY_TOKEN" \
  -u "http://$DOCKER_API_SERVICE_NAME:$PORT" \
  --firebase-api-token "$FIREBASEKEY" \
  --processes-per-phase "$EXPECTED_WORKERS" \
  --dataset-name "Drebin" \
  --email "$USERNAME" \
  --password "$PASSWORD"

WATCHER_SERVER_EXIT_CODE=$?

if [ $WATCHER_SERVER_EXIT_CODE -ne 0 ]; then
  exit_on_error "Watcher server failed to run properly"
fi

#
# STEP 7
#
step "Step 7" "Display processing results."

RESULTS_MESSAGE="Project demonstration finished.\n"

# Get the original dataset URL
DATASET_URL_RESPONSE=$(call_backend "GET" "/dataset/$DATASET_ID")
DATASET_PUBLIC_URL=$(echo "$DATASET_URL_RESPONSE" | jq -r .file.public_url)
RESULTS_MESSAGE="$RESULTS_MESSAGE\nOriginal Dataset URL: $DATASET_PUBLIC_URL\n"

# Get all processing requests and their results
PROCESSING_RESPONSE=$(call_backend "GET" "/processing")

RESULTS_MESSAGE=""
TOTAL=$(echo "$PROCESSING_RESPONSE" | jq '.edges | length')
i=0

while [ $i -lt "$TOTAL" ]; do
  node=$(echo "$PROCESSING_RESPONSE" | jq -c ".edges[$i].node")
  
  PROCESSING_ID=$(echo "$node" | jq -r .id)
  PROCESSING_STATUS=$(echo "$node" | jq -r .status)
  PROCESSING_STARTED=$(echo "$node" | jq -r .started_at)
  PROCESSING_FINISHED=$(echo "$node" | jq -r .finished_at)
  
  RESULTS_MESSAGE="${RESULTS_MESSAGE}\nProcessing Request ID: $PROCESSING_ID\n"
  RESULTS_MESSAGE="${RESULTS_MESSAGE}Status: $PROCESSING_STATUS\n"
  RESULTS_MESSAGE="${RESULTS_MESSAGE}Started: $PROCESSING_STARTED\n"
  RESULTS_MESSAGE="${RESULTS_MESSAGE}Finished: $PROCESSING_FINISHED\n"
  
  if [ "$PROCESSING_STATUS" = "SUCCEEDED" ]; then
    RESULT_URL=$(echo "$node" | jq -r .result_file.public_url)
    METRICS_URL=$(echo "$node" | jq -r .metrics_file.public_url)
    RESULTS_MESSAGE="${RESULTS_MESSAGE}\nResult File URL: $RESULT_URL\n"
    RESULTS_MESSAGE="${RESULTS_MESSAGE}\nMetrics File URL: $METRICS_URL\n"
  fi
  
  RESULTS_MESSAGE="${RESULTS_MESSAGE}__________________________________________________________________\n"
  i=$((i + 1))
done

FINAL_MESSAGE="Homepage: https://malwaredatalab.github.io/\n"
FINAL_MESSAGE="${FINAL_MESSAGE}Engineer: Luiz Felipe Laviola <luiz@laviola.dev>\n"
FINAL_MESSAGE="${FINAL_MESSAGE}Enjoy!"
GREETING=$(greeting "$FINAL_MESSAGE")
FINAL_MESSAGE="$GREETING"

stop "$RESULTS_MESSAGE\n${FINAL_MESSAGE}"
