cd frontend
gleam run -m lustre/dev build app
cp -r ./priv ../backend
cd ../backend
gleam run backend
