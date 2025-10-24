"""
PyTorch neural network for adverse event prediction.
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import numpy as np
from typing import Dict, Tuple, Optional
from ..utils.early_stopping import EarlyStopping


class ClinicalNN(nn.Module):
    """Neural network for clinical predictions."""
    
    def __init__(
        self,
        input_dim: int,
        hidden_layers: list = [256, 128, 64],
        dropout_rate: float = 0.3,
        activation: str = 'relu'
    ):
        """
        Initialize neural network.
        
        Args:
            input_dim: Number of input features
            hidden_layers: List of hidden layer sizes
            dropout_rate: Dropout probability
            activation: Activation function ('relu', 'elu', 'leaky_relu')
        """
        super(ClinicalNN, self).__init__()
        
        # Build layers
        layers = []
        prev_dim = input_dim
        
        for hidden_dim in hidden_layers:
            # Linear layer
            layers.append(nn.Linear(prev_dim, hidden_dim))
            
            # Batch normalization
            layers.append(nn.BatchNorm1d(hidden_dim))
            
            # Activation
            if activation == 'relu':
                layers.append(nn.ReLU())
            elif activation == 'elu':
                layers.append(nn.ELU())
            elif activation == 'leaky_relu':
                layers.append(nn.LeakyReLU())
            
            # Dropout
            layers.append(nn.Dropout(dropout_rate))
            
            prev_dim = hidden_dim
        
        # Output layer
        layers.append(nn.Linear(prev_dim, 1))
        layers.append(nn.Sigmoid())
        
        self.network = nn.Sequential(*layers)
        
    def forward(self, x):
        """Forward pass."""
        return self.network(x)


class NeuralNetworkTrainer:
    """Train and evaluate neural network."""
    
    def __init__(self, config: dict):
        """
        Initialize trainer.
        
        Args:
            config: Neural network configuration
        """
        self.config = config
        self.model = None
        self.device = torch.device(config['neural_network']['device'])
        
    def build_model(self, input_dim: int) -> ClinicalNN:
        """
        Build neural network model.
        
        Args:
            input_dim: Number of input features
            
        Returns:
            Neural network model
        """
        arch_config = self.config['neural_network']['architecture']
        
        model = ClinicalNN(
            input_dim=input_dim,
            hidden_layers=arch_config['hidden_layers'],
            dropout_rate=arch_config['dropout_rate'],
            activation=arch_config['activation']
        )
        
        model = model.to(self.device)
        
        print(f"\n{'='*60}")
        print("Neural Network Architecture")
        print(f"{'='*60}")
        print(model)
        print(f"\nTotal parameters: {sum(p.numel() for p in model.parameters()):,}")
        print(f"Trainable parameters: {sum(p.numel() for p in model.parameters() if p.requires_grad):,}")
        
        return model
    
    def train(
        self,
        X_train: np.ndarray,
        y_train: np.ndarray,
        X_val: np.ndarray,
        y_val: np.ndarray
    ) -> Tuple[ClinicalNN, Dict[str, list]]:
        """
        Train neural network.
        
        Args:
            X_train: Training features
            y_train: Training labels
            X_val: Validation features
            y_val: Validation labels
            
        Returns:
            Tuple of (trained_model, training_history)
        """
        print(f"\n{'='*60}")
        print("Training Neural Network")
        print(f"{'='*60}")
        
        # Build model
        self.model = self.build_model(X_train.shape[1])
        
        # Prepare data loaders
        train_loader = self._prepare_dataloader(X_train, y_train, shuffle=True)
        val_loader = self._prepare_dataloader(X_val, y_val, shuffle=False)
        
        # Setup training
        criterion = nn.BCELoss()
        optimizer = self._get_optimizer()
        
        # Early stopping
        early_stopping = EarlyStopping(
            patience=self.config['neural_network']['training']['early_stopping']['patience'],
            min_delta=self.config['neural_network']['training']['early_stopping']['min_delta'],
            mode='max',
            verbose=True
        )
        
        # Training loop
        history = {
            'train_loss': [],
            'val_loss': [],
            'val_auc': []
        }
        
        num_epochs = self.config['neural_network']['training']['epochs']
        best_model_state = None
        
        for epoch in range(num_epochs):
            # Train
            train_loss = self._train_epoch(train_loader, criterion, optimizer)
            
            # Validate
            val_loss, val_auc = self._validate_epoch(val_loader, criterion)
            
            # Store history
            history['train_loss'].append(train_loss)
            history['val_loss'].append(val_loss)
            history['val_auc'].append(val_auc)
            
            # Print progress
            if (epoch + 1) % 10 == 0:
                print(f"Epoch [{epoch+1}/{num_epochs}] - "
                      f"Train Loss: {train_loss:.4f}, "
                      f"Val Loss: {val_loss:.4f}, "
                      f"Val AUC: {val_auc:.4f}")
            
            # Early stopping check
            if early_stopping(val_auc, epoch):
                best_model_state = self.model.state_dict()
                break
            
            # Save best model
            if val_auc >= early_stopping.best_score:
                best_model_state = self.model.state_dict()
        
        # Load best model
        if best_model_state is not None:
            self.model.load_state_dict(best_model_state)
            print(f"\n✓ Loaded best model from epoch {early_stopping.best_epoch}")
        
        return self.model, history
    
    def _prepare_dataloader(
        self,
        X: np.ndarray,
        y: np.ndarray,
        shuffle: bool = True
    ) -> DataLoader:
        """Prepare PyTorch DataLoader."""
        # Convert to tensors
        X_tensor = torch.FloatTensor(X).to(self.device)
        y_tensor = torch.FloatTensor(y.values if hasattr(y, 'values') else y).unsqueeze(1).to(self.device)
        
        # Create dataset
        dataset = TensorDataset(X_tensor, y_tensor)
        
        # Create dataloader
        batch_size = self.config['neural_network']['training']['batch_size']
        loader = DataLoader(
            dataset,
            batch_size=batch_size,
            shuffle=shuffle,
            drop_last=False
        )
        
        return loader
    
    def _get_optimizer(self) -> optim.Optimizer:
        """Get optimizer."""
        lr = self.config['neural_network']['training']['learning_rate']
        weight_decay = self.config['neural_network']['training']['weight_decay']
        
        optimizer = optim.Adam(
            self.model.parameters(),
            lr=lr,
            weight_decay=weight_decay
        )
        
        return optimizer
    
    def _train_epoch(
        self,
        loader: DataLoader,
        criterion: nn.Module,
        optimizer: optim.Optimizer
    ) -> float:
        """Train one epoch."""
        self.model.train()
        total_loss = 0
        
        for X_batch, y_batch in loader:
            # Forward pass
            y_pred = self.model(X_batch)
            loss = criterion(y_pred, y_batch)
            
            # Backward pass
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item() * len(X_batch)
        
        return total_loss / len(loader.dataset)
    
    def _validate_epoch(
        self,
        loader: DataLoader,
        criterion: nn.Module
    ) -> Tuple[float, float]:
        """Validate one epoch."""
        from sklearn.metrics import roc_auc_score
        
        self.model.eval()
        total_loss = 0
        all_preds = []
        all_labels = []
        
        with torch.no_grad():
            for X_batch, y_batch in loader:
                # Forward pass
                y_pred = self.model(X_batch)
                loss = criterion(y_pred, y_batch)
                
                total_loss += loss.item() * len(X_batch)
                
                # Store predictions
                all_preds.extend(y_pred.cpu().numpy())
                all_labels.extend(y_batch.cpu().numpy())
        
        avg_loss = total_loss / len(loader.dataset)
        auc = roc_auc_score(all_labels, all_preds)
        
        return avg_loss, auc
    
    def predict(self, X: np.ndarray) -> np.ndarray:
        """
        Predict probabilities.
        
        Args:
            X: Features
            
        Returns:
            Predicted probabilities
        """
        self.model.eval()
        
        X_tensor = torch.FloatTensor(X).to(self.device)
        
        with torch.no_grad():
            y_pred = self.model(X_tensor)
        
        return y_pred.cpu().numpy().flatten()
    
    def save_model(self, path: str):
        """Save model to disk."""
        torch.save({
            'model_state_dict': self.model.state_dict(),
            'config': self.config
        }, path)
        print(f"✓ Model saved to: {path}")
    
    def load_model(self, path: str, input_dim: int):
        """Load model from disk."""
        checkpoint = torch.load(path, map_location=self.device)
        self.config = checkpoint['config']
        self.model = self.build_model(input_dim)
        self.model.load_state_dict(checkpoint['model_state_dict'])
        print(f"✓ Model loaded from: {path}")