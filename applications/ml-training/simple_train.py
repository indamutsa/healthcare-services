"""
Simple training script without MLflow registration.
"""

import yaml
import pickle
import os
from utils.data_loader import FeatureStoreLoader
from models.preprocessor import DataPreprocessor
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
import xgboost as xgb
from sklearn.metrics import roc_auc_score


def main():
    """Run simple training pipeline."""
    # Load configuration
    config_path = "configs/model_config.yaml"
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    print("Loading data...")
    loader = FeatureStoreLoader(config)
    df = loader.load_data()
    X, y, timestamps, feature_names = loader.prepare_features(df)
    X_train, X_val, X_test, y_train, y_val, y_test = loader.temporal_split(X, y, timestamps)
    loader.close()
    
    print("Preprocessing...")
    preprocessor = DataPreprocessor(config)
    X_train, X_val, X_test = preprocessor.fit_transform(X_train, X_val, X_test)
    
    print("Training models...")
    results = {}
    
    # Logistic Regression
    print("Training Logistic Regression...")
    lr = LogisticRegression(**config['models']['logistic_regression']['params'])
    lr.fit(X_train, y_train)
    y_val_pred = lr.predict_proba(X_val)[:, 1]
    lr_auc = roc_auc_score(y_val, y_val_pred)
    results['logistic_regression'] = {'model': lr, 'auc': lr_auc}
    print(f"  Logistic Regression AUC: {lr_auc:.4f}")
    
    # Random Forest
    print("Training Random Forest...")
    rf = RandomForestClassifier(**config['models']['random_forest']['params'])
    rf.fit(X_train, y_train)
    y_val_pred = rf.predict_proba(X_val)[:, 1]
    rf_auc = roc_auc_score(y_val, y_val_pred)
    results['random_forest'] = {'model': rf, 'auc': rf_auc}
    print(f"  Random Forest AUC: {rf_auc:.4f}")
    
    # XGBoost
    print("Training XGBoost...")
    xgb_model = xgb.XGBClassifier(**config['models']['xgboost']['params'])
    xgb_model.fit(X_train, y_train)
    y_val_pred = xgb_model.predict_proba(X_val)[:, 1]
    xgb_auc = roc_auc_score(y_val, y_val_pred)
    results['xgboost'] = {'model': xgb_model, 'auc': xgb_auc}
    print(f"  XGBoost AUC: {xgb_auc:.4f}")
    
    # Find best model
    best_model_name = max(results, key=lambda x: results[x]['auc'])
    best_model = results[best_model_name]['model']
    best_auc = results[best_model_name]['auc']
    
    print(f"\nBest model: {best_model_name} (AUC: {best_auc:.4f})")
    
    # Save best model and preprocessor
    os.makedirs('./artifacts', exist_ok=True)
    with open('./artifacts/best_model.pkl', 'wb') as f:
        pickle.dump(best_model, f)
    
    with open('./artifacts/preprocessor.pkl', 'wb') as f:
        pickle.dump(preprocessor, f)
    
    print("Models saved to ./artifacts/")
    
    # Also save to MLflow manually
    try:
        import mlflow
        mlflow.set_tracking_uri('http://mlflow-server:5000')
        mlflow.set_experiment('clinical_adverse_events')
        
        with mlflow.start_run(run_name=best_model_name):
            mlflow.log_metric('val_auc', best_auc)
            
            if best_model_name == 'xgboost':
                mlflow.xgboost.log_model(best_model, "model")
            else:
                mlflow.sklearn.log_model(best_model, "model")
            
            # Register the model
            model_uri = f"runs:/{mlflow.active_run().info.run_id}/model"
            model_version = mlflow.register_model(
                model_uri=model_uri,
                name="adverse-event-predictor"
            )
            print(f"Model registered: {model_version.name} v{model_version.version}")
    except Exception as e:
        print(f"MLflow registration failed: {e}")


if __name__ == "__main__":
    main()