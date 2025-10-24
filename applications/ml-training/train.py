"""
Main training script.
"""

import yaml
from training.pipeline import TrainingPipeline


def main():
    """Run training pipeline."""
    # Load configuration
    config_path = "configs/model_config.yaml"
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Initialize and run pipeline
    pipeline = TrainingPipeline(config)
    pipeline.run()


if __name__ == "__main__":
    main()