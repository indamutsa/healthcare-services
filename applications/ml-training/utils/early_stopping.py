"""
Early stopping callback for training.
"""

import numpy as np


class EarlyStopping:
    """Early stopping to prevent overfitting."""
    
    def __init__(
        self,
        patience: int = 10,
        min_delta: float = 0.001,
        mode: str = 'max',
        verbose: bool = True
    ):
        """
        Initialize early stopping.
        
        Args:
            patience: Number of epochs with no improvement to wait
            min_delta: Minimum change to qualify as improvement
            mode: 'max' for metrics to maximize, 'min' to minimize
            verbose: Print messages
        """
        self.patience = patience
        self.min_delta = min_delta
        self.mode = mode
        self.verbose = verbose
        
        self.counter = 0
        self.best_score = None
        self.early_stop = False
        self.best_epoch = 0
        
        # Set comparison operator based on mode
        if mode == 'max':
            self.is_better = lambda curr, best: curr > best + min_delta
            self.best_score = -np.inf
        else:
            self.is_better = lambda curr, best: curr < best - min_delta
            self.best_score = np.inf
    
    def __call__(self, score: float, epoch: int) -> bool:
        """
        Check if training should stop.
        
        Args:
            score: Current validation score
            epoch: Current epoch number
            
        Returns:
            True if training should stop
        """
        if self.is_better(score, self.best_score):
            # Improvement
            self.best_score = score
            self.best_epoch = epoch
            self.counter = 0
            
            if self.verbose:
                print(f"  ✓ Improvement: {score:.4f} (best so far)")
        else:
            # No improvement
            self.counter += 1
            
            if self.verbose:
                print(f"  → No improvement: {score:.4f} "
                      f"(patience {self.counter}/{self.patience})")
            
            if self.counter >= self.patience:
                self.early_stop = True
                if self.verbose:
                    print(f"\n✓ Early stopping triggered at epoch {epoch}")
                    print(f"  Best score: {self.best_score:.4f} at epoch {self.best_epoch}")
        
        return self.early_stop
    
    def reset(self):
        """Reset early stopping state."""
        self.counter = 0
        self.best_score = -np.inf if self.mode == 'max' else np.inf
        self.early_stop = False
        self.best_epoch = 0