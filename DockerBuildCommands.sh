sh 'whoami'
// Build nginx image
sh 'docker build -t nginx:latest -f nginx.Dockerfile .'
// Build ubuntu image
sh 'docker build -t ubuntu:latest -f ubuntu_escaped.Dockerfile .'
