# 🦟 Machine Learning-Based Dengue Outbreak Prediction System

A comprehensive AI-driven system designed to support dengue outbreak monitoring, prediction, and decision-making in the Colombo District, Sri Lanka.

This project integrates multiple intelligent components including data engineering, machine learning prediction, explainable analytics, knowledge-based NLP, and a reinforcement learning-based intervention optimization agent.

---

## 📌 Problem Statement

Dengue fever remains a major public health issue in Sri Lanka, especially in urban areas like Colombo. Existing systems mainly rely on historical analysis and lack:

- Early outbreak prediction
- Explainability of predictions
- Intelligent decision support for interventions

---

## 🎯 Objectives

- Predict dengue outbreak risk levels (Low / Medium / High)
- Analyze climate and temporal patterns
- Provide explainable insights for decision-makers
- Extract knowledge from dengue-related textual sources
- Recommend optimal intervention strategies using AI

---

## 🧩 System Components

### 1️⃣ Reinforcement Learning-Based Dengue Intervention Optimization Agent (IT22243980)
This component focuses on AI-driven decision-making for dengue control.

- Uses Reinforcement Learning (Q-Learning / DQN)
- Learns optimal intervention strategies from historical data
- Considers dengue case levels, climate conditions, and risk factors
- Outputs ranked intervention recommendations with confidence scores

---

### 2️⃣ Data Visualization & Explainable Analytics (IT22165848)
- Interactive dashboards for dengue monitoring
- Climate–dengue correlation analysis
- Temporal trend visualization
- Explainable AI (SHAP, feature importance)
- GIS-based dengue risk mapping

---

### 3️⃣ Knowledge-Augmented NLP Framework (IT22281982)
- Extracts dengue-related knowledge from:
  - Health guidelines
  - Research publications
  - News sources
- Builds vector database and knowledge graph
- Implements Retrieval-Augmented Generation (RAG)

---

### 4️⃣ Data Engineering & Machine Learning-Based Dengue Prediction (IT22214034)
- Data collection (NDCU + Meteorology)
- Data cleaning and preprocessing
- Feature engineering (time-lag features)
- Creation of ML-ready datasets

Machine Learning:
- Models: Random Forest, XGBoost, LSTM
- Time-series validation techniques
- Output:
  - Risk level classification (Low / Medium / High)
  - Outbreak probability predictions

---

### 5️⃣ Reinforcement Learning-Based Dengue Intervention Optimization Agent (IT22243980)

This component introduces an AI-driven decision-making system for optimizing dengue control strategies.

Unlike prediction modules, this component focuses on recommending the most effective intervention actions based on current outbreak conditions.

- Uses Reinforcement Learning (Q-Learning / DQN)
- Learns optimal strategies using historical dengue and climate data
- Provides ranked intervention recommendations
- Supports public health decision-making

✅ This component is fully independent from the prediction pipeline.

---

## 🏗️ System Architecture

Main Pipeline:

Data Sources (NDCU + Weather)
        ↓
Data Engineering (IT22214034)
        ↓
Machine Learning Prediction (IT22214034)
        ↓
Risk Levels
        ↓
Visualization Dashboard + XAI (IT22165848)

NLP Knowledge Base (IT22281982)
        ↓
Insights

--------------------------------------

Independent Decision-Making Module:

Reinforcement Learning Agent (IT22243980)
        ↓
Intervention Recommendations


---

## 🛠️ Technologies Used

- Python (Pandas, NumPy)
- Scikit-learn, XGBoost
- TensorFlow / PyTorch
- HuggingFace Transformers
- ChromaDB / Pinecone
- Neo4j
- React, Chart.js / Plotly
- Leaflet / Mapbox
- Reinforcement Learning (Q-Learning / DQN)

---

## 📊 Data Sources

- National Dengue Control Unit (Sri Lanka)
- Department of Meteorology (Sri Lanka)
- Public health publications

---

## 👥 Team Members

- IT22243980 – Reinforcement Learning Intervention Agent
- IT22165848 – Data Visualization & Explainable Analytics
- IT22281982 – Knowledge-Augmented NLP Framework
- IT22214034 – Data Engineering & Machine Learning Prediction
  
---

## 💡 Conclusion

This project provides a complete AI-driven dengue surveillance system that combines prediction, explainability, knowledge extraction, and intelligent decision-making to support effective public health interventions.
