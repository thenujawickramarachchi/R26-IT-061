import pandas as pd
import joblib

model = joblib.load("models/random_forest_dengue_model.pkl")
label_encoder = joblib.load("models/label_encoder.pkl")
model_features = joblib.load("models/model_features.pkl")

df = pd.read_csv("data/Dengue_ML_Ready.csv")

X = df[model_features]

predictions = model.predict(X)
predicted_labels = label_encoder.inverse_transform(predictions)

df["predicted_outbreak_level"] = predicted_labels

high_rows = df[df["predicted_outbreak_level"] == "High"]

print("High prediction rows count:", len(high_rows))

cols_to_show = model_features + ["predicted_outbreak_level"]
print(high_rows[cols_to_show].head(10).to_string())