# **Defocus Sign Classification from Retinal Images**
The project simulates human eye optics using ISETBio and trains a CNN to classify the sign of defocus (+1D vs -1D) from chromatic aberration patterns in retinal images.

## Pipeline
1. **MATLAB (ISETBio)** - Generate aberrated retinal images
                        - Wavefron optics with Zernike Coefficients
                        - Human Longitudinal Chromatic Aberration (LCA) model
                        - LMS cone response conversion
                        - 1000 images from BSDS500 dataset

2. **Python (PyTorch)** - Train CNN classifier
                        - Binary Classification, +1D vs -1D defocus
                        - 98.67% test accuracy
                        - Grad-CAM visualization

## Repository Structure
matlab/  MATLAB dataset generation function (requires ISETBio)
python/  Colab training notebook
results/ Figures and saved model

## Requirements
**MATLAB:**
- ISETBio toolbox
- BSDS500 dataset images

**Python:**
- PyTorch
- scipy
- numpy
- matplotlib
- scikit-learn

## Results

- Test Accuracy: 98.67%
- 2 misclassifications out of 150 test samples
- Grad-CAM analysis suggests network focuses on edge regions, consistent with chromatic aberration signal location
