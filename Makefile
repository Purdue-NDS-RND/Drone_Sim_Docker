.PHONY: run build rebuild validate down logs

run:
	./run.sh

build:
	./run.sh --build-only

rebuild:
	docker compose -f compose.yaml -f compose.gpu.yaml build --no-cache

validate:
	bash -n run.sh start-sim.sh sitl-process-wrapper.sh
	XAUTH_FILE=/dev/null DISPLAY=:0 HOST_UID=$$(id -u) HOST_GID=$$(id -g) docker compose -f compose.yaml config --quiet

down:
	./run.sh --down

logs:
	docker compose -f compose.yaml logs -f simulator
