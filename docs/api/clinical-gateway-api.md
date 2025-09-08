# Navigate to your project directory
cd applications/clinical-data-gateway

# Download and install all dependencies
mvn dependency:resolve

# Or do a clean install (downloads deps + compiles)
mvn clean install

# Just download dependencies without compiling
mvn dependency:go-offline

---

Great! Now you have a working clinical data gateway that can accept REST calls and route them to IBM MQ queues.

Let's test the complete flow:

## Next Steps

**1. Start the Spring Boot application:**
```bash
cd applications/clinical-data-gateway
mvn spring-boot:run
```

**2. Test the health endpoint:**
```bash
curl http://localhost:8080/actuator/health
```

**3. Run your Python data generator:**
```bash
cd /workspaces/clinical-trials-service
python3 operations/scripts/demo/clinical_data_generator.py --endpoint http://localhost:8080 --interval 5-15 --count 10
```

## What Should Happen

The data flow will be:
- Python generator creates realistic clinical data
- POST to `http://localhost:8080/api/clinical/data`
- Spring Boot validates the clinical data
- Routes to appropriate IBM MQ queue (vital signs, lab results, adverse events, demographics)
- Critical data goes to priority queue

## For Your Interview Demo

You can monitor:
- **Application logs** showing message processing
- **Test the health endpoint directly**: `curl http://localhost:8080/api/clinical/health`
- **Stats endpoint**: `http://localhost:8080/api/clinical/stats`
- **Queue routing** based on data type and severity

The architecture demonstrates enterprise patterns: domain modeling, validation, message routing, monitoring, and HIPAA compliance considerations.

Try the health check first to confirm the application started correctly, then run the generator to see the complete clinical trial data pipeline in action.