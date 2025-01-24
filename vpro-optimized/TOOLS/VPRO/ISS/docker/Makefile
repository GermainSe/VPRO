build:
	@docker build -t  iss_local .

start_once:
	@docker run -it --rm --name iss iss_local

deploy:
	@docker login git.rz.tu-bs.de:4567
	@docker build -t git.rz.tu-bs.de:4567/theoretische-informatik/ti/intern/04_tools/vpro/vpro_iss .
	@docker push git.rz.tu-bs.de:4567/theoretische-informatik/ti/intern/04_tools/vpro/vpro_iss

# TODO

.PHONY: build start_once deploy
