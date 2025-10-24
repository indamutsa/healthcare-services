# MLOps Deep Dive: Healthcare Clinical Trials Interview Prep

## The Conversation

**Alex (Senior ML Engineer):** So you're interviewing for a senior role focused on MLOps in healthcare. Let me walk you through a real-world scenario we handled - predicting patient adverse events in clinical trials. This'll cover everything from model building to production deployment.

**Jordan (Inquisitive Engineer):** Perfect. I've built models before, but I want to understand the full operational picture. Let's start from the beginning - what does the data pipeline even look like in clinical trials?

**Alex:** Great question. Clinical trial data is messy and comes from multiple sources. You've got Electronic Health Records streaming in real-time, lab results that come in batches, patient-reported outcomes through mobile apps, and historical trial data sitting in data warehouses. 

In our setup, we use **Apache Kafka** as the central nervous system. Real-time patient vitals and adverse event reports stream through Kafka topics. We have separate topics for different data types - one for vital signs, another for lab results, one for medication adherence. Each topic is partitioned by trial site to handle the load.

**Jordan:** Wait, why Kafka specifically? Why not just write directly to a database?

**Alex:** Think of Kafka as a buffer that decouples data producers from consumers. When a patient reports a symptom through their app, that event hits Kafka immediately. But you might have five different consumers - one writing to your data lake, another triggering real-time alerts, one feeding your ML model, another updating dashboards, and maybe one sending to a legacy system through IBM MQ for regulatory compliance.

**Jordan:** IBM MQ? That seems old-school.

**Alex:** It is, but healthcare is heavily regulated. Many hospital systems and regulatory bodies still use IBM MQ for guaranteed message delivery. We have a Kafka-to-MQ bridge because we can't just rip out decades-old infrastructure. The MQ queues handle communication with the hospital's internal systems and regulatory reporting databases that require strict audit trails.

**Jordan:** Got it. So Kafka feeds into where exactly? How do we store all this?

**Alex:** We use a medallion architecture in our data lake on S3. Raw data lands in the bronze layer - exactly as it came from Kafka, immutable and complete. Then we use **Apache Spark** to transform and clean data into the silver layer.

Here's where it gets interesting: Spark runs on Kubernetes clusters that auto-scale based on data volume. During end-of-day processing when all trial sites sync their daily reports, we might spin up 50 worker nodes. At 3 AM, maybe just 5 nodes are running.

**Jordan:** Walk me through the Spark transformation. What does "clean" actually mean for clinical data?

**Alex:** Excellent question. In the silver layer transformation, we're doing several things. First, we're deduplicating records because patient data often comes from multiple sources. If a patient's blood pressure is recorded by both the trial app and the hospital EHR, we need deduplication logic based on timestamps and source reliability.

Second, we're standardizing units. One site measures weight in pounds, another in kilograms. Lab values come in different units depending on the lab. Spark jobs apply transformation rules to normalize everything.

Third, and this is critical for ML - we're handling missing data intelligently. Clinical data has missing values for legitimate reasons. A patient skipped a lab visit, or a test wasn't applicable to them. We create missingness indicators as separate features because the pattern of what's missing is often predictive.

**Jordan:** That makes sense. Now, about features - everyone talks about feature engineering, but what does that concretely mean in this context?

**Alex:** Let me break it down properly. Features are the input variables your model uses to make predictions. In our adverse event prediction model, we don't just feed raw values. 

Take heart rate as an example. The raw heart rate value at a single point in time isn't that informative. But we engineer features like: heart rate variance over the last 24 hours, deviation from the patient's baseline, rate of change over the last week, and whether the heart rate crosses certain clinical thresholds.

Each of these derived features captures different aspects of the patient's condition. We also create interaction features - like combining medication dosage with liver enzyme levels, because certain drugs become toxic at high doses when liver function is impaired.

**Jordan:** How do you manage all these features? That sounds like hundreds of features to track.

**Alex:** That's where **feature stores** come in. We use Feast as our feature store. Think of it as a specialized database optimized for ML features. 

Here's the key insight: features need to be computed consistently whether you're training a model or serving predictions in production. Feast ensures that the exact same transformation code runs in both contexts. You define a feature once, and Feast handles serving it during training from your data warehouse and serving it in real-time during inference.

Feast also handles point-in-time correct joins. This is crucial in healthcare because you can't use future data to predict the past. When training on historical data, Feast ensures each training example only uses features that existed at that point in time.

**Jordan:** Okay, that's smart. Now let's talk about the model itself. How do you actually build and train it?

**Alex:** We use **PyTorch** for the deep learning components. Our model is actually an ensemble - a PyTorch neural network for capturing complex non-linear patterns, combined with a gradient boosted tree model for interpretability.

The neural architecture is a temporal convolutional network because we're dealing with time series patient data. Each patient's journey through the trial is a sequence. We use 1D convolutions over time to capture temporal patterns - like if heart rate and blood pressure both trend upward over three days, that's a different signal than random fluctuations.

**Jordan:** Walk me through the training process operationally. How does code become a trained model?

**Alex:** Here's the full pipeline. Data scientists work in notebooks initially, experimenting with architectures and hyperparameters. When they have something promising, they convert it to production-grade Python scripts.

We use **MLflow** to track everything. Every training run logs hyperparameters, metrics, and artifacts to MLflow. So if a data scientist tries a different learning rate or adds a layer to the network, MLflow records it. We can compare hundreds of runs and see exactly what configuration produced the best validation performance.

**Jordan:** What's validation in this context? I hear that term thrown around.

**Alex:** Validation is how we test if our model actually works before deploying it to production. You split your data into three sets: training, validation, and test.

The model learns from the training set. But during training, after each epoch, you evaluate on the validation set - data the model hasn't seen. This tells you if the model is actually learning generalizable patterns or just memorizing the training data, which we call overfitting.

The test set is held out until the very end. You never touch it during development. Only when you think you have a final model do you evaluate on the test set to get an unbiased estimate of real-world performance.

**Jordan:** But couldn't you just keep tweaking the model until the validation performance is perfect?

**Alex:** Exactly! That's called validation set overfitting. If you make hundreds of decisions based on validation performance - which features to include, which architecture to use, which hyperparameters to set - you're indirectly overfitting to the validation set.

That's why **cross-validation** exists. Instead of one validation split, you do k-fold cross-validation. You split the data into, say, 5 folds. Train on 4 folds, validate on the 5th. Then train on a different set of 4 folds, validate on the remaining fold. Repeat until every fold has been the validation set once. 

You average the performance across all 5 folds. This gives you a more robust estimate because your validation performance isn't dependent on one particular split of the data.

**Jordan:** That makes sense, but doesn't that mean training 5 models?

**Alex:** Yes, and in production systems, that's expensive. For our clinical trial model, one training run takes 6 hours on a GPU cluster. So k-fold cross-validation would take 30 hours. We use cross-validation during initial model development to select the architecture. But for daily retraining in production, we use a single hold-out validation set.

**Jordan:** Daily retraining? Why retrain so frequently?

**Alex:** Clinical trials evolve. Patient populations shift as the trial progresses - maybe healthier patients stay in the trial longer, creating survival bias. Treatment protocols might be adjusted mid-trial based on interim results. If we don't retrain, our model's predictions become stale.

This brings us to **model monitoring** and **drift detection**. We track two types of drift: data drift and concept drift.

**Jordan:** Break those down for me.

**Alex:** Data drift means the input distribution changes. Maybe the average age of enrolled patients increases over time. Or perhaps lab measurement devices get recalibrated, shifting the distribution of lab values. We detect this by comparing the statistical distribution of incoming features against the distribution from training data.

We use the **Kolmogorov-Smirnov test** for continuous features and **chi-square tests** for categorical features. If the p-value drops below a threshold, we flag that feature as drifting.

Concept drift is different - the relationship between inputs and outputs changes. Maybe a medication's effectiveness changes over time as patients develop tolerance. Or seasonal factors affect adverse event rates. We detect concept drift by monitoring model performance metrics on recent data.

**Jordan:** What metrics specifically?

**Alex:** For our adverse event prediction, we track several metrics in production. **AUROC** (area under the ROC curve) tells us how well the model separates patients who will have adverse events from those who won't. We need an AUROC above 0.85 or we retrain.

**Precision and recall** are tracked separately because they have different clinical implications. High precision means when we predict an adverse event, we're usually right - this matters because false alarms cause alarm fatigue. High recall means we catch most actual adverse events - this matters for patient safety.

We also track **calibration**. If the model says there's a 30% chance of an adverse event, then across all patients where the model outputs 30%, roughly 30% should actually experience adverse events. Calibration drift is often the first sign something's wrong.

**Jordan:** How do you actually track these metrics in production?

**Alex:** We use **Prometheus** to collect metrics and **Grafana** for dashboards. Every prediction the model makes gets logged with ground truth labels once the outcome is known. A background job computes rolling metrics over different time windows - last hour, last day, last week.

When AUROC drops below threshold or calibration error exceeds limits, we get alerts. We also use **Evidently AI** which generates detailed drift reports comparing production data distributions against training data distributions.

**Jordan:** Now about versioning - I've heard about DVC. How does that fit in?

**Alex:** **DVC** (Data Version Control) is like Git for data and models. Here's the critical thing to understand: Git is great for code, but terrible for large files. Our training dataset is 500GB. Our trained model files are 2GB. You can't commit that to Git.

DVC works alongside Git. You commit a small metadata file to Git - it's just a pointer file with a hash. DVC stores the actual large files in S3. When you run `dvc pull`, it downloads the actual data based on those pointers.

But here's where it gets more sophisticated. We actually use **LakeFS** in addition to DVC. LakeFS provides Git-like branching and versioning directly on top of S3. It's designed for data lakes.

**Jordan:** Wait, so you're using both DVC and LakeFS? Why?

**Alex:** They serve different purposes. DVC is tightly integrated with our ML pipeline - it versions datasets, model files, and metrics together with the code that produced them. When you check out a Git commit, DVC can recreate the exact data environment for that commit.

LakeFS operates at a different level. It versions the entire data lake. We use LakeFS for data lineage and atomic snapshots. When our Spark jobs transform bronze data to silver, LakeFS commits create an atomic snapshot. If the job fails halfway, we can roll back. We can also create branches to test new transformation logic without affecting production data.

**Jordan:** So Git handles code, DVC handles ML artifacts tied to that code, and LakeFS handles the raw data lake. Is that right?

**Alex:** Exactly. Think of it as layers. LakeFS is the foundation - the data lake itself is versioned. DVC sits on top - it versions specific datasets extracted from the lake plus model artifacts. Git is at the top - it versions the code that orchestrates everything.

In practice, our DVC pipeline definitions reference LakeFS commits. So a training pipeline might say "use data from LakeFS commit abc123" and DVC ensures that specific version is used reproducibly.

**Jordan:** This is making sense. Now what about orchestration? How do all these pieces run together?

**Alex:** We use **Kubeflow Pipelines** running on Kubernetes. Kubeflow is specifically designed for ML workflows. A pipeline is a directed acyclic graph of steps - data validation, preprocessing, feature engineering, training, evaluation, and deployment.

Each step runs in its own container with exactly the dependencies it needs. The feature engineering step uses a container with Spark and Feast. The training step uses a container with PyTorch and CUDA for GPU support. The evaluation step uses a container with our metrics calculation libraries.

**Jordan:** Why Kubeflow over something like Airflow?

**Alex:** Airflow is great for general data pipelines, but Kubeflow has ML-specific features. It integrates with Katib for hyperparameter tuning - Katib runs multiple training jobs in parallel with different hyperparameters and finds the optimal combination. Kubeflow also has built-in support for distributed training across multiple GPUs.

More importantly, Kubeflow pipelines produce artifacts that are automatically versioned and tracked in MLflow. There's less glue code to write.

**Jordan:** Tell me about hyperparameter tuning. How does that work operationally?

**Alex:** Hyperparameters are the settings you configure before training - learning rate, number of layers, dropout rate, batch size, etc. Unlike model parameters which are learned during training, hyperparameters are set by the engineer.

**Katib** automates the search through hyperparameter space. You define a search space - maybe learning rate between 0.0001 and 0.01, number of layers between 2 and 8, dropout between 0.1 and 0.5. Katib uses algorithms like Bayesian optimization or hyperband to intelligently search this space.

It launches dozens or hundreds of training jobs, each with different hyperparameter combinations. Early stopping kills jobs that are clearly performing poorly to save compute. The best performing configuration becomes your production model.

**Jordan:** Where does the actual model deployment happen?

**Alex:** Our trained model gets packaged as a Docker container with a FastAPI serving layer. This gets deployed to Kubernetes using **Seldon Core**, which provides advanced deployment patterns for ML models.

We use **canary deployments**. The new model version gets deployed alongside the existing version. Initially, only 5% of prediction traffic routes to the new model. We monitor performance and error rates. If the new model performs well, we gradually increase traffic to 10%, 25%, 50%, until eventually 100% of traffic goes to the new model and we retire the old version.

If the new model shows problems - higher latency, lower AUROC, or serving errors - we automatically roll back. Seldon Core makes this seamless.

**Jordan:** What about latency requirements? Clinical predictions need to be fast, right?

**Alex:** Absolutely. We have a strict 100ms p99 latency requirement. When a clinician opens a patient's dashboard, they can't wait seconds for predictions.

This is why we use feature stores correctly. Feast serves features from Redis for online serving - sub-millisecond lookups. The model itself runs on CPU inference servers for most predictions. We only use GPU servers for batch predictions overnight.

We also use **ONNX** (Open Neural Network Exchange) to optimize the PyTorch model. ONNX Runtime performs graph optimizations and quantization to make inference faster without sacrificing accuracy.

**Jordan:** What about model explainability? In healthcare, you can't just have a black box.

**Alex:** Critical point. We compute **SHAP** (SHapley Additive exPlanations) values for every prediction. SHAP tells you which features contributed most to the prediction and by how much.

When the model predicts a high adverse event risk, the clinician sees something like: "60% risk driven by: elevated liver enzymes (+15%), increasing heart rate variance (+12%), medication interaction (+8%)..." This is actionable.

We also maintain a simpler decision tree model as a backup. It's less accurate than the neural network, but completely interpretable. For audits or challenging cases, we can show exactly how the tree reached its decision.

**Jordan:** How do you handle model retraining in production? Is it fully automated?

**Alex:** We have automated retraining triggered by two conditions: time-based (every 7 days) and performance-based (when AUROC drops below 0.85).

The retraining pipeline pulls fresh data from the last 90 days, runs feature engineering, trains a new model with the same architecture but new weights, evaluates on a hold-out set, and if performance beats the current production model, initiates a canary deployment.

**Jordan:** What if retraining makes the model worse?

**Alex:** That's why we have automated evaluation gates. The new model must exceed the current production model's performance on the hold-out set by at least 2% on AUROC. If it doesn't, the pipeline halts and alerts the team.

We also maintain a model registry in MLflow with all historical model versions. If something goes wrong, we can promote an older model version back to production within minutes.

**Jordan:** Walk me through the metadata. What gets stored where?

**Alex:** Great question because metadata is what makes everything reproducible. 

In **Git**, we store code, pipeline definitions, and DVC metadata files. The DVC files contain hashes pointing to data and model artifacts.

In **DVC/S3**, we store actual datasets (training data, validation data), trained model weights, and preprocessors (like fitted scalers and encoders).

In **MLflow**, we store run metadata for every training job - hyperparameters, metrics (loss, AUROC, precision, recall), training duration, who triggered it, which code commit was used, and links to model artifacts. MLflow is our source of truth for "what model is in production and how did we train it?"

In **LakeFS**, we store data lake snapshots and branches. Each pipeline run references a LakeFS commit hash.

In **Feast**, we store feature definitions and feature metadata - what transformations create each feature, data types, value ranges, and timestamps.

**Jordan:** That's a lot of systems. How do they stay in sync?

**Alex:** Through careful orchestration. Each Kubeflow pipeline step logs its outputs to multiple systems. After training completes, we log to MLflow (metrics), push to DVC (model files), tag in Git (code version), and record in LakeFS (data version).

We use correlation IDs - a single unique ID that flows through all systems for a given training run. So you can trace from a production prediction back through Seldon to the model version, through MLflow to the training run, through DVC to the exact data version, through Git to the code, and through LakeFS to the raw data snapshot.

**Jordan:** What about monitoring in production beyond model metrics? Like infrastructure monitoring?

**Alex:** We run the full observability stack. **Prometheus** scrapes metrics from Kubernetes pods - CPU, memory, request rates, error rates. **Grafana** dashboards show real-time system health.

For distributed tracing, we use **Jaeger**. When a prediction request comes in, we can trace it through the entire stack - from the API gateway, through feature store lookups, through model inference, to the response. If latency spikes, we can pinpoint exactly which component slowed down.

**Jordan:** Last question - disaster recovery. What if everything breaks?

**Alex:** We have several layers. First, model rollback - we keep the last 5 production models and can redeploy any of them in under 5 minutes.

Second, we have blue-green environments. Production runs in the blue environment. We maintain a complete duplicate green environment. For major changes, we deploy to green, test thoroughly, then swap the load balancer to point traffic to green. Blue becomes the new standby.

Third, all data and models are replicated across AWS regions. If the entire primary region goes down, we can failover to the backup region. This takes about 15 minutes because we need to update DNS and warm up the inference servers.

Fourth, we maintain a simplified fallback model that runs on CPU with minimal dependencies. If the entire ML infrastructure fails, we can serve predictions from this fallback model which runs on basic infrastructure.

**Jordan:** This is incredibly comprehensive. I feel like I understand not just the tools, but why each piece exists and how they fit together.

**Alex:** That's exactly the point. In interviews, they're not just checking if you know buzzwords like "Kubeflow" or "MLflow". They want to see if you understand the engineering tradeoffs - why you'd choose Kafka over direct database writes, why you need both validation sets and test sets, why feature stores matter, how drift detection prevents model decay.

The tools are just implementations of core principles: reproducibility, monitoring, scalability, and reliability. If you understand those principles, you can adapt to any tech stack.

**Jordan:** One more thing - what's the biggest operational challenge you've faced?

**Alex:** Data quality from multiple trial sites. Different sites use different Electronic Health Record systems, different lab equipment, different data entry practices. We spent months building validation pipelines with Great Expectations to catch data quality issues early.

We learned that no matter how sophisticated your model is, if the input data is garbage, your predictions will be garbage. MLOps isn't just about model serving - it's about the entire data-to-decision pipeline, and data quality is the foundation.

The second biggest challenge was organizational - getting clinicians to trust ML predictions. We built trust through transparency (SHAP explanations), validation (prospective studies showing model performance), and collaboration (regular feedback sessions with clinical staff). Technology is only half the battle in healthcare ML.

**Jordan:** Thanks for the deep dive. This is exactly what I needed.

**Alex:** Good luck with the interview. Remember, show you understand the why, not just the what.

---

## Quick Reference: Key Concepts

**Data Pipeline:**
- Kafka: Real-time event streaming
- IBM MQ: Legacy system integration for regulatory compliance
- Spark on Kubernetes: Distributed data processing with auto-scaling
- Medallion architecture: Bronze (raw) → Silver (cleaned) → Gold (aggregated)

**ML Pipeline:**
- PyTorch: Deep learning framework
- MLflow: Experiment tracking and model registry
- DVC: Data and model versioning alongside Git
- LakeFS: Data lake versioning with Git-like semantics
- Feast: Feature store for consistent feature serving

**Orchestration & Deployment:**
- Kubeflow Pipelines: ML workflow orchestration
- Katib: Hyperparameter tuning
- Seldon Core: Model serving with canary deployments
- ONNX Runtime: Optimized inference

**Monitoring:**
- Prometheus + Grafana: Metrics and dashboards
- Evidently AI: Data drift detection
- Jaeger: Distributed tracing
- SHAP: Model explainability

**Key Technical Concepts:**
- Features: Engineered input variables, not raw data
- Validation vs Test sets: Validation for development, test for final unbiased evaluation
- Cross-validation: Multiple train/validation splits for robust evaluation
- Data drift: Input distribution changes
- Concept drift: Input-output relationship changes
- Point-in-time correctness: No future data leakage in historical training
- Calibration: Predicted probabilities match actual frequencies