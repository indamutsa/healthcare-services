```sh
docker ps -a --filter "name=lab" --format 'table {{.Names}}\t{{.Status}}'   
```