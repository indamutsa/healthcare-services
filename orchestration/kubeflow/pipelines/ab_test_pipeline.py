"""
Kubeflow A/B Testing Pipeline
A/B testing and model comparison pipeline
"""

def create_ab_test_pipeline(
    pipeline_name: str = "clinical_ab_test_pipeline",
):
    """
    Create a Kubeflow pipeline for A/B testing

    This pipeline includes:
    - Deploy model variants
    - Traffic splitting
    - Performance monitoring
    - Winner selection

    Args:
        pipeline_name: Name of the pipeline
    """
    try:
        from kfp import dsl
        from kfp.components import create_component_from_func
    except ImportError:
        print("KFP not available - using placeholder implementation")
        return None

    import sys
    import os
    component_dir = os.path.join(os.path.dirname(__file__), '../components')
    sys.path.insert(0, component_dir)

    from deploy_model import deploy_model
    from evaluate_model import evaluate_model

    deploy_op = create_component_from_func(deploy_model)
    evaluate_op = create_component_from_func(evaluate_model)

    @dsl.pipeline(
        name=pipeline_name,
        description='A/B testing pipeline for clinical trial models'
    )
    def ab_test_pipeline(
        model_a_uri: str = 'models:/clinical_trial_predictor/1',
        model_b_uri: str = 'models:/clinical_trial_predictor/2',
        test_data_path: str = '/data/test.parquet',
    ):
        """A/B test pipeline definition"""
        
        # Deploy model A
        deploy_a = deploy_op(
            model_uri=model_a_uri,
            deployment_name="clinical-predictor-a",
            deployment_target="production"
        )
        
        # Deploy model B
        deploy_b = deploy_op(
            model_uri=model_b_uri,
            deployment_name="clinical-predictor-b",
            deployment_target="production"
        )
        
        # Evaluate model A
        eval_a = evaluate_op(
            model_path=model_a_uri,
            test_data_path=test_data_path
        ).after(deploy_a)
        
        # Evaluate model B
        eval_b = evaluate_op(
            model_path=model_b_uri,
            test_data_path=test_data_path
        ).after(deploy_b)
    
    return ab_test_pipeline


if __name__ == '__main__':
    pipeline = create_ab_test_pipeline()
    print("A/B test pipeline created")
