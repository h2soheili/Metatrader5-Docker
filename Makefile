build:
	docker build -t mymt5 .

run: build
	docker run --rm -dit -p 5900:5900 -p 15555:15555 -p 15556:15556 -p 15557:15557 -p 15558:15558 --name mymt5 -v mymt5:/data mymt5

shell: 
	docker exec -it mymt5 bash

users: build
	docker exec -it mymt5 adduser novouser
