# Start the application
```sh
mvn clean spring-boot:run
```


# CURRENT ISSUES

• I'll put together a concise summary covering what’s been done so far, including key failures like the model-serving error due to missing
  models and training failures from Docker mount path issues. I’ll mention the user’s request about tracking and crossing off TODOs, note that
  some are still outstanding, and reference relevant commands and problems without changing files.

─ Worked for 6s ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

• Level 4 wiring and scripts are in place and the cascade logic works: ./pipeline-manager.sh --start --level 4 now auto-starts Levels 0–
  3 before bringing up MLflow and model-serving, just as designed. Health checks for MLflow itself pass (scripts/ml-layer/health-checks.sh
  validates the container plus /health and /api/2.0/mlflow/experiments/list), so the tracking server is healthy.

  Current blockers:

  - model-serving still exits because MLflow has no registered model yet (docker logs model-serving shows adverse-event-predictor missing).
    Until a model is trained and registered, Level 4 status will remain “partially running”.
  - The training helper (./pipeline-manager.sh --level 4 --run-training) can’t launch the container: Docker denies mounting applications/ml-
    training because that host path isn’t shared with Docker in this environment.

  Once the volume-sharing issue is resolved and a training run registers a model, model-serving should stay up and Level 4 will report fully
  healthy.
