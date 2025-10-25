"""
Test script to validate ml-training setup.
"""

import sys
import yaml


def test_imports():
    """Test all critical imports."""
    print("Testing imports...")
    try:
        import mlflow
        import xgboost
        import torch
        import pandas
        import sklearn
        from pyspark.sql import SparkSession
        print("  ✓ All dependencies imported")
    except ImportError as e:
        print(f"  ✗ Import failed: {e}")
        return False
    return True


def test_modules():
    """Test custom modules."""
    print("\nTesting custom modules...")
    try:
        from training.pipeline import TrainingPipeline
        from training.model_trainer import ModelTrainer
        from models.preprocessor import DataPreprocessor
        from models.neural_net import NeuralNetworkTrainer
        from utils.metrics import MetricsCalculator
        from utils.data_loader import FeatureStoreLoader
        print("  ✓ All custom modules imported")
    except ImportError as e:
        print(f"  ✗ Module import failed: {e}")
        return False
    return True


def test_config():
    """Test configuration loading."""
    print("\nTesting configuration...")
    try:
        with open('configs/model_config.yaml', 'r') as f:
            config = yaml.safe_load(f)

        # Check key sections
        assert 'experiment' in config, "Missing experiment section"
        assert 'models' in config, "Missing models section"
        assert 'data' in config, "Missing data section"

        # Count enabled models
        enabled_models = sum(1 for m in config['models'].values() if m.get('enabled'))
        print(f"  ✓ Configuration valid ({enabled_models} models enabled)")

    except Exception as e:
        print(f"  ✗ Config test failed: {e}")
        return False
    return True


def test_java():
    """Test Java installation for Spark."""
    print("\nTesting Java installation...")
    import subprocess
    try:
        result = subprocess.run(['java', '-version'],
                              capture_output=True, text=True)
        if result.returncode == 0:
            version_line = result.stderr.split('\n')[0]
            print(f"  ✓ Java installed: {version_line}")
            return True
        else:
            print("  ✗ Java not working")
            return False
    except Exception as e:
        print(f"  ✗ Java test failed: {e}")
        return False


def main():
    """Run all tests."""
    print("="*60)
    print("ML-Training Setup Validation")
    print("="*60)

    results = []
    results.append(("Imports", test_imports()))
    results.append(("Modules", test_modules()))
    results.append(("Configuration", test_config()))
    results.append(("Java", test_java()))

    print("\n" + "="*60)
    print("Test Results")
    print("="*60)

    all_passed = True
    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{test_name:20s} {status}")
        if not passed:
            all_passed = False

    print("="*60)

    if all_passed:
        print("✓ All tests passed! ML-Training is ready to run.")
        return 0
    else:
        print("✗ Some tests failed. Please check the errors above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
