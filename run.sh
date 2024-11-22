cd frontend
gleam run -m lustre/dev build app
cp -r ./priv/static ../backend/priv/static
cd ../backend
gleam run backend
