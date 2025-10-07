 *Kafka verification checklist*:

* what topics exist,
* their configuration,
* how many messages they have, and
* what’s inside each stream.

Below is a **complete workflow** you can follow **step-by-step inside your Kafka container** (Bitnami or Confluent image using non-`.sh` binaries).

---

## 🧭 0️⃣ Enter the Kafka container

```bash
docker exec -it kafka bash
```

> Replace `kafka` with your actual container name (e.g. `clinical-kafka-1` or `broker`).

---

## ⚙️ 1️⃣ Set a helper environment variable

Inside the container:

```bash
export BS=localhost:9092
```

If your Python producer connects using something like `kafka:29092`, then set that instead:
>
```bash
export BS=kafka:29092
```

---

## 📜 2️⃣ List all topics

```bash
kafka-topics --bootstrap-server "$BS" --list
```

✅ You should see something like:

```
patient-vitals
lab-results
medications
adverse-events
```

---

## 🧩 3️⃣ Describe each topic

```bash
kafka-topics --bootstrap-server "$BS" --describe --topic patient-vitals
```

Typical output:

```
Topic: patient-vitals  PartitionCount: 1  ReplicationFactor: 1  Configs: segment.bytes=1073741824
    Topic: patient-vitals  Partition: 0  Leader: 1  Replicas: 1  Isr: 1
```

Repeat for others:

```bash
for t in lab-results medications adverse-events; do
  echo "----- $t -----"
  kafka-topics --bootstrap-server "$BS" --describe --topic $t
done
```

---

## 🧮 4️⃣ Check how many messages are in each topic

Kafka doesn’t show counts directly, but **offsets ≈ number of messages**.

### a) Get end offsets (latest position)

```bash
kafka-get-offsets --bootstrap-server "$BS" --topic patient-vitals --time -1
```

Example output:

```
patient-vitals:0:14532
```

➡️ **14532 messages** have been written so far to partition 0.

### b) Get beginning offsets (oldest position)

```bash
kafka-get-offsets --bootstrap-server "$BS" --topic patient-vitals --time -2
```

Example:

```
patient-vitals:0:0
```

### c) Compute message count

You can subtract begin from end:

```bash
end=$(kafka-get-offsets --bootstrap-server "$BS" --topic patient-vitals --time -1 | awk -F: '{sum+=$3} END{print sum}')
begin=$(kafka-get-offsets --bootstrap-server "$BS" --topic patient-vitals --time -2 | awk -F: '{sum+=$3} END{print sum}')
echo "patient-vitals message count: $((end-begin))"
```

Repeat for all topics:

```bash
for t in patient-vitals lab-results medications adverse-events; do
  end=$(kafka-get-offsets --bootstrap-server "$BS" --topic $t --time -1 | awk -F: '{sum+=$3} END{print sum}')
  begin=$(kafka-get-offsets --bootstrap-server "$BS" --topic $t --time -2 | awk -F: '{sum+=$3} END{print sum}')
  echo "$t → $((end-begin)) messages"
done
```

---

## 👀 5️⃣ See what’s inside (inspect messages)

### a) View 10 messages from start:

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals \
  --from-beginning \
  --max-messages 10
```

### b) Pretty-print JSON (optional, if `jq` is installed)

```bash
kafka-console-consumer --bootstrap-server "$BS" --topic patient-vitals --from-beginning --max-messages 3 | jq
```

### c) Tail live stream (new data as produced)

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals
```

> Press **Ctrl + C** to exit.

---

## 🔁 6️⃣ Repeat for other topics

You can quickly peek a few messages from each:

```bash
for t in lab-results medications adverse-events; do
  echo "----- $t -----"
  kafka-console-consumer --bootstrap-server "$BS" --topic $t --from-beginning --max-messages 5
done
```

---

## 🧑‍💻 7️⃣ (Optional) Produce a manual test message

```bash
kafka-console-producer --bootstrap-server "$BS" --topic patient-vitals
```

Paste a JSON record, then press **Ctrl +D**:

```
{"patient_id":"PT99999","timestamp":"2025-10-07T16:45:00Z","heart_rate":91,"blood_pressure_systolic":125,"spo2":97,"trial_site":"Paris","trial_arm":"treatment"}
```

---

## 🚪 8️⃣ Exit the container

```bash
exit
```

---

### ✅ Quick Recap of What Each Step Gives You

| Step | Command                   | What You Learn                  |
| ---- | ------------------------- | ------------------------------- |
| 2    | `kafka-topics --list`     | Which topics exist              |
| 3    | `kafka-topics --describe` | Partitions, replication, config |
| 4    | `kafka-get-offsets`       | Approx. number of messages      |
| 5    | `kafka-console-consumer`  | Actual message content          |
| 7    | `kafka-console-producer`  | Manual test publishing          |

---

**watch messages live in the terminal** — like `tail -f` for logs — using the built-in CLI consumer.
Here’s exactly how to do that, step by step 👇

---

## 🧭 1️⃣ Enter the Kafka container

```bash
docker exec -it kafka bash
```

Then set a broker helper (adjust host if needed):

```bash
export BS=localhost:9092
```

---

## 👁️ 2️⃣ Live-tail messages from a topic

The simplest way to “see data live” as your producer sends it is:

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals
```

➡️ This will **continuously stream new messages** to your terminal as they arrive.
Every message your Python producer pushes to `patient-vitals` will appear instantly.

> Press **Ctrl + C** to stop watching.

---

## 🧩 3️⃣ Make the output more informative (optional)

You can show timestamps, headers, or partition info:

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals \
  --property print.timestamp=true \
  --property print.partition=true \
  --property print.headers=true
```

---

## 🧠 4️⃣ Start from the latest (not from the beginning)

If you only want to see **new messages arriving from now on** (not old history):

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals \
  --from-beginning=false
```

---

## 🧾 5️⃣ Watch multiple topics at once (handy for clinical data)

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals,lab-results,medications,adverse-events
```

You’ll see all events interleaved as they stream in.

---

## 🧰 6️⃣ Advanced (colorize / pretty-print JSON)

If your container has `jq` installed (or you can `apt install jq`):

```bash
kafka-console-consumer \
  --bootstrap-server "$BS" \
  --topic patient-vitals \
  --from-beginning=false \
  | jq
```

This will format and color the JSON for readability.

---

## ⚙️ 7️⃣ Example: typical live view output

You’ll see something like this scroll by:

```json
{"patient_id":"PT00231","timestamp":"2025-10-07T17:01:30Z","heart_rate":82,"blood_pressure_systolic":119,"blood_pressure_diastolic":78,"temperature":36.8,"spo2":97,"source":"bedside_monitor","trial_site":"Milan","trial_arm":"treatment"}
{"patient_id":"PT00072","timestamp":"2025-10-07T17:01:33Z","heart_rate":98,"blood_pressure_systolic":142,"blood_pressure_diastolic":90,"temperature":37.1,"spo2":96,"source":"telemetry","trial_site":"Madrid","trial_arm":"control"}
```

---

✅ **Summary**

| Goal                            | Command                                                                  |
| ------------------------------- | ------------------------------------------------------------------------ |
| Watch live data                 | `kafka-console-consumer --bootstrap-server "$BS" --topic patient-vitals` |
| Only new messages               | add `--from-beginning=false`                                             |
| Include timestamps & partitions | add `--property print.timestamp=true --property print.partition=true`    |
| Watch all topics                | `--topic patient-vitals,lab-results,medications,adverse-events`          |

---
