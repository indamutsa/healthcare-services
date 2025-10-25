"""
Kubeflow Training Pipeline
End-to-end model training pipeline for clinical trials
"""

def create_training_pipeline(
    experiment_name: str = "clinical_trials_training",
    pipeline_name: str = "clinical_training_pipeline",
):
    """
    Create a Kubeflow pipeline for model training

    This pipeline includes:
    - Data validation
    - Feature engineering  
    - Model training
    - Model evaluation
    - Model registration

    Args:
        experiment_name: Name of the MLflow experiment
        pipeline_name: Name of the pipeline
    """
    try:
        from kfp import dsl
        from kfp.components import create_component_from_func
    except ImportError:
        print("KFP not available - using placeholder implementation")
        return None

    # Import component functions
    import sys
    import os
    component_dir = os.path.join(os.path.dirname(__file__), '../components')
    sys.path.insert(0, component_dir)

    from data_validation import validate_data
    from feature_engineering import engineer_features
    from train_model import train_model
    from evaluate_model import evaluate_model
    from register_model import register_model

    # Create KFP components
    validate_op = create_component_from_func(validate_data)
    engineer_features_op = create_component_from_func(engineer_features)
    train_op = create_component_from_func(train_model)
    evaluate_op = create_component_from_func(evaluate_model)
    register_op = create_component_from_func(register_model)

    @dsl.pipeline(
        name=pipeline_name,
        description='End-to-end clinical trial model training pipeline'
    )
    def training_pipeline(
        data_path: str = '/data/clinical_data.parquet',
        model_name: str = 'clinical_trial_predictor',
        model_type: str = 'random_forest',
    ):
        """Training pipeline definition"""
        
        # Step 1: Validate data
        validation_task = validate_op(
            input_data_path=data_path
        )
        
        # Step 2: Engineer features
        feature_task = engineer_features_op(
            input_data_path=data_path
        ).after(validation_task)
        
        # Step 3: Train model
        train_task = train_op(
            training_data_path=feature_task.outputs['features_path'],
            validation_data_path=data_path,
            model_type=model_type
        )
        
        # Step 4: Evaluate model
        eval_task = evaluate_op(
            model_path=train_task.outputs['model_path'],
            test_data_path=data_path
        )
        
        # Step 5: Register model if evaluation passes
        register_task = register_op(
            model_path=train_task.outputs['model_path'],
            model_name=model_name
        ).after(eval_task)
    
    return training_pipeline


if __name__ == '__main__':
    pipeline = create_training_pipeline()
    print("Training pipeline created")
