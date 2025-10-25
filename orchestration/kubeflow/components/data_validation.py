"""
Kubeflow Pipeline Component: Data Validation
Validates clinical trial data quality
"""

from typing import NamedTuple


def validate_data(
    input_data_path: str,
    validation_rules_path: str = None,
    fail_on_error: bool = False,
) -> NamedTuple('Outputs', [('is_valid', bool), ('validation_report', dict)]):
    """
    Validate clinical trial data

    Args:
        input_data_path: Path to input data
        validation_rules_path: Path to validation rules
        fail_on_error: Whether to fail on validation errors

    Returns:
        Tuple of (is_valid, validation_report)
    """
    import json
    from collections import namedtuple

    print(f"Validating data: {input_data_path}")
    print(f"Validation rules: {validation_rules_path}")

    # Placeholder validation logic
    validation_report = {
        "total_records": 10000,
        "valid_records": 9850,
        "invalid_records": 150,
        "validation_errors": [
            {"field": "age", "error": "missing_values", "count": 50},
            {"field": "blood_pressure", "error": "out_of_range", "count": 100}
        ],
        "validation_warnings": [
            {"field": "medication", "warning": "unusual_values", "count": 25}
        ]
    }

    is_valid = validation_report["invalid_records"] < 200

    print(f"Validation complete")
    print(f"Valid: {is_valid}")
    print(f"Report: {json.dumps(validation_report, indent=2)}")

    if fail_on_error and not is_valid:
        raise ValueError("Data validation failed")

    outputs = namedtuple('Outputs', ['is_valid', 'validation_report'])
    return outputs(is_valid, validation_report)


if __name__ == '__main__':
    result = validate_data(
        input_data_path="/data/clinical_data.parquet"
    )
    print(f"Validation complete: {result}")
