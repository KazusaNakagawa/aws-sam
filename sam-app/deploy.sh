# 引数で環境名を受け取ります（例: dev, prod）
ENV=$1

# 引数をチェックして、もし引数がなければスクリプトを終了します。
echo "Deploying to $ENV"

if [ -z "$ENV" ]; then
  echo "Usage: $0 <env>"
  exit 1
fi

# SAMのデプロイコマンドを実行します。設定ファイル名には引数を含めます。
# sam deploy --config-file "${ENV}_samconfig.toml"
# 適用コマンド OK 確認する　y/n
echo "sam deploy --config-env ${ENV}"
# read -p "OK? (y/n): " yn
# case "$yn" in [yY]*) ;; *) echo "Aborted." ; exit ;; esac

sam deploy --config-env $ENV
