"""
Evaluation metrics for clinical predictions.
"""

import numpy as np
import pandas as pd
from sklearn.metrics import (
    roc_auc_score,
    average_precision_score,
    precision_recall_curve,
    roc_curve,
    confusion_matrix,
    classification_report
)
from typing import Dict, Tuple
import matplotlib.pyplot as plt
import seaborn as sns


class MetricsCalculator:
    """Calculate comprehensive evaluation metrics."""
    
    @staticmethod
    def calculate_all_metrics(
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        threshold: float = 0.5
    ) -> Dict[str, float]:
        """
        Calculate all evaluation metrics.
        
        Args:
            y_true: True labels
            y_pred_proba: Predicted probabilities
            threshold: Classification threshold
            
        Returns:
            Dictionary of metrics
        """
        # Binary predictions
        y_pred = (y_pred_proba >= threshold).astype(int)
        
        # ROC AUC
        roc_auc = roc_auc_score(y_true, y_pred_proba)
        
        # PR AUC
        pr_auc = average_precision_score(y_true, y_pred_proba)
        
        # Confusion matrix
        tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
        
        # Calculate clinical metrics
        sensitivity = tp / (tp + fn) if (tp + fn) > 0 else 0  # Recall
        specificity = tn / (tn + fp) if (tn + fp) > 0 else 0
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0  # PPV
        npv = tn / (tn + fn) if (tn + fn) > 0 else 0
        
        # F1 and accuracy
        f1 = 2 * (precision * sensitivity) / (precision + sensitivity) if (precision + sensitivity) > 0 else 0
        accuracy = (tp + tn) / (tp + tn + fp + fn)
        
        return {
            # Primary metrics
            'roc_auc': roc_auc,
            'pr_auc': pr_auc,
            
            # Clinical metrics
            'sensitivity': sensitivity,
            'specificity': specificity,
            'precision': precision,
            'npv': npv,
            'f1_score': f1,
            'accuracy': accuracy,
            
            # Confusion matrix
            'tp': int(tp),
            'tn': int(tn),
            'fp': int(fp),
            'fn': int(fn),
            
            # Threshold used
            'threshold': threshold
        }
    
    @staticmethod
    def find_optimal_threshold(
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        target_recall: float = 0.80
    ) -> Tuple[float, Dict[str, float]]:
        """
        Find optimal threshold for target recall.
        
        Args:
            y_true: True labels
            y_pred_proba: Predicted probabilities
            target_recall: Target recall/sensitivity
            
        Returns:
            Tuple of (optimal_threshold, metrics)
        """
        precisions, recalls, thresholds = precision_recall_curve(y_true, y_pred_proba)
        
        # Find threshold closest to target recall
        idx = np.argmin(np.abs(recalls - target_recall))
        optimal_threshold = thresholds[idx] if idx < len(thresholds) else 0.5
        
        # Calculate metrics at optimal threshold
        metrics = MetricsCalculator.calculate_all_metrics(
            y_true, y_pred_proba, optimal_threshold
        )
        
        return optimal_threshold, metrics
    
    @staticmethod
    def plot_roc_curve(
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        model_name: str = "Model",
        save_path: str = None
    ):
        """Plot ROC curve."""
        fpr, tpr, _ = roc_curve(y_true, y_pred_proba)
        roc_auc = roc_auc_score(y_true, y_pred_proba)
        
        plt.figure(figsize=(8, 6))
        plt.plot(fpr, tpr, label=f'{model_name} (AUC = {roc_auc:.3f})', linewidth=2)
        plt.plot([0, 1], [0, 1], 'k--', label='Random', linewidth=1)
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title('ROC Curve')
        plt.legend(loc="lower right")
        plt.grid(alpha=0.3)
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            plt.close()
        
        return plt.gcf() if not save_path else None
    
    @staticmethod
    def plot_precision_recall_curve(
        y_true: np.ndarray,
        y_pred_proba: np.ndarray,
        model_name: str = "Model",
        save_path: str = None
    ):
        """Plot precision-recall curve."""
        precisions, recalls, _ = precision_recall_curve(y_true, y_pred_proba)
        pr_auc = average_precision_score(y_true, y_pred_proba)
        
        plt.figure(figsize=(8, 6))
        plt.plot(recalls, precisions, label=f'{model_name} (AP = {pr_auc:.3f})', linewidth=2)
        plt.xlim([0.0, 1.0])
        plt.ylim([0.0, 1.05])
        plt.xlabel('Recall')
        plt.ylabel('Precision')
        plt.title('Precision-Recall Curve')
        plt.legend(loc="lower left")
        plt.grid(alpha=0.3)
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            plt.close()
        
        return plt.gcf() if not save_path else None
    
    @staticmethod
    def plot_confusion_matrix(
        y_true: np.ndarray,
        y_pred: np.ndarray,
        save_path: str = None
    ):
        """Plot confusion matrix."""
        cm = confusion_matrix(y_true, y_pred)
        
        plt.figure(figsize=(8, 6))
        sns.heatmap(
            cm,
            annot=True,
            fmt='d',
            cmap='Blues',
            xticklabels=['No Event', 'Adverse Event'],
            yticklabels=['No Event', 'Adverse Event'],
            cbar_kws={'label': 'Count'}
        )
        plt.ylabel('True Label')
        plt.xlabel('Predicted Label')
        plt.title('Confusion Matrix')
        
        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            plt.close()
        
        return plt.gcf() if not save_path else None