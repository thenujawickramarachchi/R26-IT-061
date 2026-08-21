import os
import smtplib
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from supabase import create_client


load_dotenv()

app = Flask(__name__)
CORS(app)

SYSTEM_NAME = "Dengue RL Intervention Optimization Agent"
VERSION = "Prototype v0.6"

ACTIONS = [
    "Monitor Only",
    "Deploy Fumigation Teams",
    "Issue Public Health Alert",
    "Increase Hospital Readiness",
    "Community Cleanup Campaign",
]

SENDER_EMAIL = os.getenv("SENDER_EMAIL")
SENDER_PASSWORD = os.getenv("SENDER_PASSWORD")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase_client = None

try:
    if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY:
        supabase_client = create_client(
            SUPABASE_URL,
            SUPABASE_SERVICE_ROLE_KEY,
        )
        print("Supabase connected successfully.")
    else:
        print("Supabase connection details are missing in .env file.")

except Exception as e:
    print("Supabase connection error:", e)


try:
    q_table = np.load("q_table_real.npy", allow_pickle=True)
    print("Q-table loaded successfully:", q_table.shape)
except Exception as e:
    q_table = None
    print("Q-table load error:", e)


def current_time():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def get_moh_areas_from_db():
    """Load MOH areas from Supabase; no area names are stored in code."""
    if supabase_client is None:
        return None, "Supabase is not connected."

    try:
        result = (
            supabase_client.table("moh_areas")
            .select("name")
            .order("name")
            .execute()
        )
        areas = [row["name"] for row in result.data if row.get("name")]

        if not areas:
            return None, "No MOH areas were found in the database."

        return areas, None

    except Exception as e:
        print("MOH areas database lookup error:", str(e))
        return None, f"Database lookup failed: {str(e)}"


def get_phi_officer_from_db(area_name):
    if supabase_client is None:
        return None, None, "Supabase is not connected."

    try:
        area_result = (
            supabase_client.table("moh_areas")
            .select("id")
            .eq("name", area_name)
            .execute()
        )

        if not area_result.data:
            return None, None, f"MOH area '{area_name}' was not found."

        moh_area_id = area_result.data[0]["id"]

        phi_result = (
            supabase_client.table("phi_officers")
            .select("id, full_name, email")
            .eq("moh_area_id", moh_area_id)
            .eq("is_active", True)
            .limit(1)
            .execute()
        )

        if not phi_result.data:
            return moh_area_id, None, f"No active PHI officer found for {area_name}."

        return moh_area_id, phi_result.data[0], None

    except Exception as e:
        print("PHI database lookup error:", str(e))
        return None, None, f"Database lookup failed: {str(e)}"


def save_warning_history(
    moh_area_id,
    phi_officer,
    cases,
    rainfall,
    temperature,
    risk_level,
    top_action,
    email_result,
):
    if supabase_client is None or moh_area_id is None:
        return

    try:
        supabase_client.table("warning_history").insert(
            {
                "moh_area_id": moh_area_id,
                "phi_officer_id": phi_officer["id"] if phi_officer else None,
                "dengue_cases": cases,
                "rainfall_mm": rainfall,
                "temperature_c": temperature,
                "risk_level": risk_level,
                "recommended_action": top_action,
                "recipient_email": email_result.get("receiver"),
                "email_sent": email_result.get("sent", False),
                "email_message": email_result.get("message"),
            }
        ).execute()

        print("Warning history saved successfully.")

    except Exception as e:
        print("Warning history save error:", str(e))


def validate_input(area, cases, rainfall, temperature):
    errors = []

    areas, database_error = get_moh_areas_from_db()
    if database_error:
        errors.append(database_error)
    elif not area:
        errors.append("MOH area is required.")
    elif area not in areas:
        errors.append("Invalid MOH area. Please select an area from the database list.")

    if cases <= 0:
        errors.append("Dengue cases must be greater than 0.")

    if rainfall < 0:
        errors.append("Rainfall cannot be negative.")

    if temperature < 0:
        errors.append("Temperature cannot be negative.")

    if temperature > 60:
        errors.append("Temperature value is too high. Please check the input.")

    return errors


def get_risk_level(cases, rainfall, temperature):
    if cases >= 5000 or (cases >= 3000 and rainfall >= 15):
        return "HIGH"
    elif cases >= 1500 or rainfall >= 10:
        return "MEDIUM"
    else:
        return "LOW"


def get_risk_interpretation(risk_level):
    if risk_level == "HIGH":
        return (
            "Urgent dengue intervention is required. "
            "The situation indicates a high possibility of outbreak growth, "
            "therefore immediate PHI/MOH action is recommended."
        )

    if risk_level == "MEDIUM":
        return (
            "Moderate dengue risk detected. "
            "Preventive actions should be taken before the situation becomes critical."
        )

    return (
        "The current situation is stable. "
        "Regular monitoring and preventive awareness should continue."
    )


def get_action_explanation(risk_level, top_action):
    if risk_level == "HIGH":
        return (
            f"High dengue cases combined with rainfall and temperature conditions "
            f"can increase mosquito breeding risk. Therefore, '{top_action}' is recommended "
            f"as the priority intervention."
        )

    if risk_level == "MEDIUM":
        return (
            f"The area shows a moderate dengue risk. "
            f"'{top_action}' can help prevent the situation from escalating."
        )

    return (
        f"The risk level is currently low. "
        f"'{top_action}' is suitable for continued monitoring and prevention."
    )


def get_levels(cases, rainfall, temperature):
    if cases < 1500:
        case_level = 0
    elif cases < 5000:
        case_level = 1
    else:
        case_level = 2

    if rainfall < 10:
        rain_level = 0
    elif rainfall < 20:
        rain_level = 1
    else:
        rain_level = 2

    if temperature < 26:
        temp_level = 0
    elif temperature < 30:
        temp_level = 1
    else:
        temp_level = 2

    return case_level, rain_level, temp_level


def fallback_recommendations(risk_level):
    if risk_level == "HIGH":
        return [
            {"rank": 1, "action": "Deploy Fumigation Teams", "confidence": 89.9},
            {"rank": 2, "action": "Issue Public Health Alert", "confidence": 6.3},
            {"rank": 3, "action": "Community Cleanup Campaign", "confidence": 1.9},
        ]

    if risk_level == "MEDIUM":
        return [
            {"rank": 1, "action": "Community Cleanup Campaign", "confidence": 62.5},
            {"rank": 2, "action": "Issue Public Health Alert", "confidence": 24.0},
            {"rank": 3, "action": "Monitor Only", "confidence": 13.5},
        ]

    return [
        {"rank": 1, "action": "Monitor Only", "confidence": 75.0},
        {"rank": 2, "action": "Community Cleanup Campaign", "confidence": 18.0},
        {"rank": 3, "action": "Increase Hospital Readiness", "confidence": 7.0},
    ]


def get_recommendations(cases, rainfall, temperature):
    risk_level = get_risk_level(cases, rainfall, temperature)

    if q_table is None:
        return fallback_recommendations(risk_level)

    try:
        case_level, rain_level, temp_level = get_levels(cases, rainfall, temperature)

        if len(q_table.shape) == 4:
            q_values = q_table[case_level, rain_level, temp_level]
        else:
            state_index = case_level * 9 + rain_level * 3 + temp_level
            state_index = max(0, min(state_index, q_table.shape[0] - 1))
            q_values = q_table[state_index]

        q_values = np.asarray(q_values, dtype=float).flatten()

        if len(q_values) < len(ACTIONS):
            print("Q-table action count mismatch. Using fallback.")
            return fallback_recommendations(risk_level)

        q_values = q_values[: len(ACTIONS)]
        sorted_indices = np.argsort(q_values)[::-1]

        shifted = q_values - np.min(q_values)

        if np.sum(shifted) == 0:
            probabilities = np.ones(len(q_values)) / len(q_values)
        else:
            probabilities = shifted / np.sum(shifted)

        recommendations = []

        for rank, action_index in enumerate(sorted_indices[:3], start=1):
            action_index = int(action_index)

            recommendations.append(
                {
                    "rank": rank,
                    "action": ACTIONS[action_index],
                    "confidence": round(float(probabilities[action_index] * 100), 1),
                }
            )

        return recommendations

    except Exception as e:
        print("Recommendation error. Fallback used:", str(e))
        return fallback_recommendations(risk_level)


def send_phi_email(
    receiver_email,
    receiver_name,
    area,
    cases,
    rainfall,
    temperature,
    risk_level,
    top_action,
):
    if not SENDER_EMAIL or not SENDER_PASSWORD:
        return {
            "sent": False,
            "message": "Email not sent. Missing SENDER_EMAIL or SENDER_PASSWORD in .env file.",
            "receiver": receiver_email,
        }

    subject = f"HIGH Dengue Risk Alert - {area}"

    body = f"""
Dear {receiver_name},

A HIGH dengue risk situation has been detected by the Dengue RL Intervention Optimization Agent.

MOH Area: {area}
Cases: {cases}
Rainfall: {rainfall} mm
Temperature: {temperature} °C
Risk Level: {risk_level}

Recommended Intervention:
{top_action}

System Explanation:
{get_action_explanation(risk_level, top_action)}

Please take necessary public health action as soon as possible.

Regards,
Dengue RL Intervention Optimization Agent
AI-Powered Decision Support System
"""

    try:
        message = MIMEMultipart()
        message["From"] = SENDER_EMAIL
        message["To"] = receiver_email
        message["Subject"] = subject
        message.attach(MIMEText(body, "plain"))

        server = smtplib.SMTP_SSL("smtp.gmail.com", 465)
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(SENDER_EMAIL, receiver_email, message.as_string())
        server.quit()

        print(f"Email sent successfully to {receiver_email}")

        return {
            "sent": True,
            "message": f"Warning email sent to {receiver_name}.",
            "receiver": receiver_email,
        }

    except Exception as e:
        print("Email sending error:", str(e))

        return {
            "sent": False,
            "message": f"Email sending failed: {str(e)}",
            "receiver": receiver_email,
        }

def build_recommendation_response(area, cases, rainfall, temperature):
    risk_level = get_risk_level(cases, rainfall, temperature)
    recommendations = get_recommendations(cases, rainfall, temperature)
    top_action = recommendations[0]["action"]

    email_result = {
        "sent": False,
        "message": "Risk level is not HIGH. Email not required.",
        "receiver": None,
    }

    return {
        "success": True,
        "timestamp": current_time(),
        "system": SYSTEM_NAME,
        "version": VERSION,
        "area": area,
        "cases": cases,
        "rainfall": rainfall,
        "temperature": temperature,
        "risk_level": risk_level,
        "risk_interpretation": get_risk_interpretation(risk_level),
        "recommendations": recommendations,
        "top_action": top_action,
        "recommendation_explanation": get_action_explanation(risk_level, top_action),
        "email": email_result,
    }


@app.route("/", methods=["GET"])
def home():
    return jsonify(
        {
            "status": "running",
            "message": "Dengue RL Backend API is running",
            "system": SYSTEM_NAME,
            "version": VERSION,
            "available_endpoints": [
                "/health",
                "/recommend",
                "/send-warning",
                "/test-email",
                "/sample/high-risk",
                "/moh-areas",
            ],
        }
    )


@app.route("/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "ok",
            "message": "Dengue RL API running!",
            "system": SYSTEM_NAME,
            "version": VERSION,
            "timestamp": current_time(),
            "q_table_loaded": q_table is not None,
            "q_table_shape": str(q_table.shape) if q_table is not None else None,
            "sender_email_found": SENDER_EMAIL is not None,
            "sender_password_found": SENDER_PASSWORD is not None,
            "supabase_connected": supabase_client is not None,
        }
    )


@app.route("/moh-areas", methods=["GET"])
def moh_areas():
    areas, database_error = get_moh_areas_from_db()

    if database_error:
        return jsonify({"success": False, "message": database_error}), 500

    return jsonify(
        {
            "success": True,
            "count": len(areas),
            "district": "Colombo",
            "areas": areas,
        }
    )


@app.route("/sample/high-risk", methods=["GET"])
def sample_high_risk():
    areas, database_error = get_moh_areas_from_db()

    if database_error:
        return jsonify({"success": False, "message": database_error}), 500

    return jsonify(
        {
            "success": True,
            "message": "Use this sample for panel/demo high-risk testing.",
            "sample": {
                "area": areas[0],
                "cases": 6000,
                "rainfall": 20,
                "temperature": 28,
            },
        }
    )


@app.route("/recommend", methods=["POST"])
def recommend():
    try:
        data = request.get_json(force=True)

        area = data.get("area")
        cases = int(data.get("cases", 0))
        rainfall = float(data.get("rainfall", 0))
        temperature = float(data.get("temperature", data.get("temp", 0)))

        validation_errors = validate_input(area, cases, rainfall, temperature)

        if validation_errors:
            return jsonify(
                {
                    "success": False,
                    "timestamp": current_time(),
                    "message": "Invalid input data.",
                    "errors": validation_errors,
                }
            ), 400

        # Recommendations do not send e-mail. E-mail is sent only by /send-warning.
        response = build_recommendation_response(
            area=area,
            cases=cases,
            rainfall=rainfall,
            temperature=temperature,
        )

        return jsonify(response)

    except Exception as e:
        print("Recommend API error:", str(e))

        return jsonify(
            {
                "success": False,
                "timestamp": current_time(),
                "message": "Recommendation API failed.",
                "error": str(e),
            }
        ), 500


@app.route("/send-warning", methods=["POST"])
def send_warning():
    try:
        data = request.get_json(force=True)

        area = data.get("area")
        cases = int(data.get("cases", 0))
        rainfall = float(data.get("rainfall", 0))
        temperature = float(data.get("temperature", data.get("temp", 0)))

        validation_errors = validate_input(area, cases, rainfall, temperature)

        if validation_errors:
            return jsonify(
                {
                    "success": False,
                    "timestamp": current_time(),
                    "message": "Invalid input data.",
                    "errors": validation_errors,
                }
            ), 400

        risk_level = get_risk_level(cases, rainfall, temperature)
        recommendations = get_recommendations(cases, rainfall, temperature)
        top_action = recommendations[0]["action"]

        # Get PHI officer details from Supabase
        moh_area_id, phi_officer, database_error = get_phi_officer_from_db(area)

        if risk_level != "HIGH":
            email_result = {
                "sent": False,
                "message": "Email not sent because risk level is not HIGH.",
                "receiver": phi_officer["email"] if phi_officer else None,
            }

        elif database_error:
            email_result = {
                "sent": False,
                "message": database_error,
                "receiver": None,
            }

        else:
            email_result = send_phi_email(
                receiver_email=phi_officer["email"],
                receiver_name=phi_officer["full_name"],
                area=area,
                cases=cases,
                rainfall=rainfall,
                temperature=temperature,
                risk_level=risk_level,
                top_action=top_action,
            )

        # Save warning result in Supabase history table
        save_warning_history(
            moh_area_id=moh_area_id,
            phi_officer=phi_officer,
            cases=cases,
            rainfall=rainfall,
            temperature=temperature,
            risk_level=risk_level,
            top_action=top_action,
            email_result=email_result,
        )

        return jsonify(
            {
                "success": email_result["sent"],
                "timestamp": current_time(),
                "area": area,
                "cases": cases,
                "rainfall": rainfall,
                "temperature": temperature,
                "risk_level": risk_level,
                "risk_interpretation": get_risk_interpretation(risk_level),
                "recommendations": recommendations,
                "top_action": top_action,
                "recommendation_explanation": get_action_explanation(
                    risk_level,
                    top_action,
                ),
                "email": email_result,
            }
        )

    except Exception as e:
        print("Send warning API error:", str(e))

        return jsonify(
            {
                "success": False,
                "timestamp": current_time(),
                "message": "Send warning API failed.",
                "error": str(e),
            }
        ), 500


@app.route("/test-email", methods=["GET"])
def test_email():
    areas, database_error = get_moh_areas_from_db()

    if database_error:
        return jsonify(
            {
                "success": False,
                "timestamp": current_time(),
                "test": "PHI email test",
                "email": {"sent": False, "message": database_error},
            }
        ), 500

    test_area = areas[0]
    _, phi_officer, database_error = get_phi_officer_from_db(test_area)

    if database_error:
        return jsonify(
            {
                "success": False,
                "timestamp": current_time(),
                "test": "PHI email test",
                "email": {"sent": False, "message": database_error},
            }
        ), 500

    result = send_phi_email(
        receiver_email=phi_officer["email"],
        receiver_name=phi_officer["full_name"],
        area=test_area,
        cases=6000,
        rainfall=20,
        temperature=28,
        risk_level="HIGH",
        top_action="Deploy Fumigation Teams",
    )

    return jsonify(
        {
            "success": result["sent"],
            "timestamp": current_time(),
            "test": "PHI email test",
            "email": result,
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)