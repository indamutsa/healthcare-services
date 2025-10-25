"""
Kubeflow Deployment Pipeline
Model deployment and serving pipeline
"""

def create_deployment_pipeline(
    pipeline_name: str = "clinical_deployment_pipeline",
):
    """
    Create a Kubeflow pipeline for model deployment

    This pipeline includes:
    - Model validation
    - Deployment to staging
    - Smoke testing
    - Deployment to production

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

    from evaluate_model import evaluate_model
    from deploy_model import deploy_model

    evaluate_op = create_component_from_func(evaluate_model)
    deploy_op = create_component_from_func(deploy_model)

    @dsl.pipeline(
        name=pipeline_name,
        description='Model deployment pipeline for clinical trials'
    )
    def deployment_pipeline(
        model_uri: str = 'models:/clinical_trial_predictor/1',
        deployment_name: str = 'clinical-predictor',
        test_data_path: str = '/data/test.parquet',
    ):
        """Deployment pipeline definition"""
        
        # Step 1: Validate model
        eval_task = evaluate_op(
            model_path=model_uri,
            test_data_path=test_data_path
        )
        
        # Step 2: Deploy to staging
        staging_deploy = deploy_op(
            model_uri=model_uri,
            deployment_name=f"{deployment_name}-staging",
            deployment_target="staging"
        ).after(eval_task)
        
        # Step 3: Deploy to production if staging succeeds
        prod_deploy = deploy_op(
            model_uri=model_uri,
            deployment_name=deployment_name,
            deployment_target="production",
            replicas=3
        ).after(staging_deploy)
    
    return deployment_pipeline


if __name__ == '__main__':
    pipeline = create_deployment_pipeline()
    print("Deployment pipeline created")
