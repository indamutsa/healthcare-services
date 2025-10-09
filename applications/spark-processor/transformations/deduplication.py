"""
Deduplication transformations.
Removes duplicate records based on business keys.
"""

from pyspark.sql import DataFrame
from pyspark.sql.functions import col, row_number
from pyspark.sql.window import Window
from typing import List


def remove_exact_duplicates(df: DataFrame) -> DataFrame:
    """
    Remove exact duplicate rows.
    
    Args:
        df: Input DataFrame
        
    Returns:
        DataFrame with exact duplicates removed
    """
    initial_count = df.count()
    df_dedup = df.dropDuplicates()
    final_count = df_dedup.count()
    
    removed = initial_count - final_count
    if removed > 0:
        print(f"  Removed {removed} exact duplicates")
    
    return df_dedup


def deduplicate_records(
    df: DataFrame,
    partition_cols: List[str],
    order_by: str = "timestamp",
    keep: str = "last"
) -> DataFrame:
    """
    Remove duplicates based on business key, keeping first or last occurrence.
    
    Args:
        df: Input DataFrame
        partition_cols: Columns that define a unique record
        order_by: Column to order by when selecting which duplicate to keep
        keep: 'first' or 'last' record to keep
        
    Returns:
        DataFrame with duplicates removed
    """
    # Create window partitioned by business key, ordered by timestamp
    if keep == "last":
        window_spec = Window.partitionBy(*partition_cols).orderBy(col(order_by).desc())
    else:
        window_spec = Window.partitionBy(*partition_cols).orderBy(col(order_by).asc())
    
    # Add row number
    df_with_row_num = df.withColumn("_row_num", row_number().over(window_spec))
    
    # Keep only first row (row_num = 1)
    df_dedup = df_with_row_num.filter(col("_row_num") == 1).drop("_row_num")
    
    return df_dedup