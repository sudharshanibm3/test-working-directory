echo "Install pre-reqs for multi-arch builds"
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt install -y docker-ce
sudo apt-get install qemu-user-static

echo "Configure buildx"
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --driver-opt network=host --use --name container-builder
docker buildx inspect --bootstrap
docker buildx use container-builder
export DOCKER_BUILDKIT=1

echo "Create test Dockerfile"
cat << EOF > ${HOME}/Dockerfile.working_dir
FROM ubuntu:22.04

RUN mkdir -p /other
WORKDIR /other/

ENTRYPOINT [ "/bin/bash", "-c", "pwd" ]
EOF

echo "Log into quay.io"
sudo docker login quay.io

echo "Create and run mutli-arch build"
cat << EOF > ${HOME}/multi-arch-build.sh
#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

registry="\${registry:-quay.io/sudharshanibm3/working_dir_test}"

supported_arches=(
	"amd64"
	"s390x"
)

function build_image() {
	arch_amends=()
	local image="\${registry}"
	for arch in \${supported_arches[@]}; do
		echo "Building image \${image} for \${arch}"
		# TODO - refactor the image name out
		# TODO - build-arg ARCH needed?
		docker buildx build \
			-f Dockerfile.working_dir \
			-t "\${image}-\${arch}" \
			--platform="\${arch}" \
			--load \
			.
		docker push "\${image}-\${arch}"
		arch_amends+=( --amend "\${image}-\${arch}")
	done

	docker manifest create \
		\${image} \
		\${arch_amends[@]}

	docker manifest push --purge \${image}
}

function main() {
	build_image
}

main "\$@"
EOF
chmod u+x ${HOME}/multi-arch-build.sh