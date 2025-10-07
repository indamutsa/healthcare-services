 **Definitive cheat sheet** 🧠 for managing Docker **containers** and **images**, especially useful when you’re cleaning up after experiments like Kafka, MinIO, or your clinical producer scripts.

---

## 🧱 **1️⃣ Containers**

### 🔍 List containers

```bash
# Running containers
docker ps

# All containers (including stopped ones)
docker ps -a
```

---

### 🛑 Stop containers

```bash
# Stop one container
docker stop <container_id_or_name>

# Stop all running containers
docker stop $(docker ps -q)
```

---

### 🗑️ Remove containers

```bash
# Remove a specific container
docker rm <container_id_or_name>

# Remove all stopped containers
docker container prune -f

# Force remove all containers (running + stopped)
docker rm -f $(docker ps -aq)
```

---

### 🧼 Stop + remove everything in one go

```bash
docker stop $(docker ps -aq) && docker rm $(docker ps -aq)
```

---

## 🖼️ **2️⃣ Images**

### 📋 List images

```bash
docker images
```

---

### 🗑️ Remove specific image

```bash
docker rmi <image_id_or_name>
```

Example:

```bash
docker rmi minio/minio:latest
```

---

### 🔥 Remove **all** unused images

```bash
docker image prune -a -f
```

> ⚠️ Deletes all images not currently used by a container.

---

### 🧹 Remove **dangling** images only (intermediate build layers)

```bash
docker image prune -f
```

---

### 🧩 Remove a specific image forcefully

```bash
docker rmi -f <image_id>
```

---

## 📦 **3️⃣ Volumes and Networks (optional cleanup)**

### 🧱 Remove unused volumes

```bash
docker volume prune -f
```

### 🌐 Remove unused networks

```bash
docker network prune -f
```

---

## 💣 **4️⃣ Full cleanup (everything)**

If you want to **reset Docker completely** — stop and remove **all containers, images, volumes, networks**:

```bash
docker system prune -a --volumes -f
```


## ⚙️ **5️⃣ Helpful combos**

### Stop and remove a single container

```bash
docker stop kafka && docker rm kafka
```

### Remove all MinIO-related containers and images

```bash
docker ps -a | grep minio
docker stop minio && docker rm minio
docker rmi minio/minio:latest
```

---

## 🧠 **6️⃣ Quick reference summary**

| Action                       | Command                                                      |
| ---------------------------- | ------------------------------------------------------------ |
| List running containers      | `docker ps`                                                  |
| Stop a container             | `docker stop <id>`                                           |
| Remove a container           | `docker rm <id>`                                             |
| Stop & remove all containers | `docker stop $(docker ps -aq) && docker rm $(docker ps -aq)` |
| List images                  | `docker images`                                              |
| Remove specific image        | `docker rmi <id>`                                            |
| Remove unused images         | `docker image prune -a -f`                                   |
| Remove volumes               | `docker volume prune -f`                                     |
| Full cleanup                 | `docker system prune -a --volumes -f`                        |

---


Excellent catch 👀 — let’s complete that part properly.
Here’s how to use **`docker rmi $(...)`** for bulk image deletion (and related useful patterns).

---

## 🧱 **Remove Docker images with `docker rmi $(...)`**

### 🗑️ Remove **all images**

```bash
docker rmi $(docker images -q)
```

> Deletes **every image** on your system.
> Add `-f` to **force remove** even if containers are using them:

```bash
docker rmi -f $(docker images -q)
```

---

### 🧹 Remove only **dangling (unnamed)** images

```bash
docker rmi $(docker images -f "dangling=true" -q)
```

> This is safer — removes intermediate build layers and `<none>` tags.

---

### 🧩 Remove images by **repository name**

Example: remove all MinIO images

```bash
docker rmi $(docker images minio/minio -q)
```

Example: remove all Kafka-related images

```bash
docker rmi $(docker images confluentinc/cp-kafka -q)
```

---

### 🧼 Stop + remove containers + images (full cleanup combo)

```bash
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker rmi $(docker images -q)
```

Or the **force version** (no prompts, removes all):

```bash
docker stop $(docker ps -aq) 2>/dev/null
docker rm -f $(docker ps -aq) 2>/dev/null
docker rmi -f $(docker images -q) 2>/dev/null
```

---

### 🔥 Full one-liner (containers + images + volumes)

```bash
docker system prune -a --volumes -f
```

---

✅ **Summary**

| Task                                  | Command                                                                                        |
| ------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Remove all images                     | `docker rmi $(docker images -q)`                                                               |
| Force remove all images               | `docker rmi -f $(docker images -q)`                                                            |
| Remove dangling images                | `docker rmi $(docker images -f "dangling=true" -q)`                                            |
| Remove specific repo images           | `docker rmi $(docker images <repo-name> -q)`                                                   |
| Stop + remove all containers + images | `docker stop $(docker ps -aq) && docker rm $(docker ps -aq) && docker rmi $(docker images -q)` |

---

