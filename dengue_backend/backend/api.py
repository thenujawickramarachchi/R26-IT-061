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
VERSION = "Prototype v0.7"

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
Q_TABLE_PATH = os.getenv("Q_TABLE_PATH", "q_table_real.npy")
RL_LEARNING_RATE = float(os.getenv("RL_LEARNING_RATE", "0.10"))
RL_DISCOUNT_FACTOR = float(os.getenv("RL_DISCOUNT_FACTOR", "0.90"))
RL_REWARD_SCALE = float(os.getenv("RL_REWARD_SCALE", "10.0"))

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
    q_table = np.load(Q_TABLE_PATH, allow_pickle=True)
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
def get_warning_history_from_db(limit=20):
    """Load saved PHI warning records from Supabase."""
    if supabase_client is None:
        return None, "Supabase is not connected."

    try:
        result = (
            supabase_client.table("warning_history")
            .select(
                "id, dengue_cases, rainfall_mm, temperature_c, risk_level, "
                "recommended_action, recipient_email, email_sent, email_message, "
                "created_at, moh_areas(name), phi_officers(full_name)"
            )
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )

        history = []

        for row in result.data:
            area = row.pop("moh_areas", None) or {}
            officer = row.pop("phi_officers", None) or {}

            row["moh_area_name"] = area.get("name", "Unknown area")
            row["phi_officer_name"] = officer.get(
                "full_name",
                "Not assigned",
            )

            history.append(row)

        return history, None

    except Exception as e:
        print("Warning history database lookup error:", str(e))
        return None, f"Database lookup failed: {str(e)}"


def get_warning_for_feedback(warning_history_id):
    """Load the original warning state used for a PHI outcome feedback record."""
    if supabase_client is None:
        return None, "Supabase is not connected."

    try:
        result = (
            supabase_client.table("warning_history")
            .select(
                "id, moh_area_id, phi_officer_id, dengue_cases, rainfall_mm, "
                "temperature_c, recommended_action"
            )
            .eq("id", warning_history_id)
            .limit(1)
            .execute()
        )

        if not result.data:
            return None, "Warning history record was not found."

        return result.data[0], None

    except Exception as e:
        print("Feedback warning lookup error:", str(e))
        return None, f"Database lookup failed: {str(e)}"


def calculate_feedback_reward(cases_before, cases_after, outcome_status):
    """Calculate a bounded reward from the observed case change and PHI outcome."""
    if cases_before <= 0:
        case_change_ratio = 0.0
    else:
        case_change_ratio = (cases_before - cases_after) / cases_before

    outcome_adjustment = {
        "improved": 1.0,
        "no_change": 0.0,
        "worsened": -1.0,
    }.get(outcome_status, 0.0)

    reward = (RL_REWARD_SCALE * case_change_ratio) + outcome_adjustment
    return round(max(-RL_REWARD_SCALE, min(RL_REWARD_SCALE, reward)), 2)


def update_q_table_from_feedback(
    cases_before,
    cases_after,
    rainfall,
    temperature,
    intervention_action,
    reward,
):
    """Apply one Q-learning update and persist the updated Q-table."""
    global q_table

    if q_table is None:
        return False, "Q-table is not loaded.", None

    if intervention_action not in ACTIONS:
        return False, "Feedback action does not match a valid RL action.", None

    try:
        action_index = ACTIONS.index(intervention_action)
        current_case_level, rain_level, temperature_level = get_levels(
            cases_before,
            rainfall,
            temperature,
        )
        next_case_level, next_rain_level, next_temperature_level = get_levels(
            cases_after,
            rainfall,
            temperature,
        )

        if len(q_table.shape) == 4:
            old_q_value = float(
                q_table[
                    current_case_level,
                    rain_level,
                    temperature_level,
                    action_index,
                ]
            )
            next_max_q = float(
                np.max(
                    q_table[
                        next_case_level,
                        next_rain_level,
                        next_temperature_level,
                    ]
                )
            )
            new_q_value = old_q_value + RL_LEARNING_RATE * (
                reward + (RL_DISCOUNT_FACTOR * next_max_q) - old_q_value
            )
            q_table[
                current_case_level,
                rain_level,
                temperature_level,
                action_index,
            ] = new_q_value

        elif len(q_table.shape) == 2:
            current_state = (
                current_case_level * 9
                + rain_level * 3
                + temperature_level
            )
            next_state = (
                next_case_level * 9
                + next_rain_level * 3
                + next_temperature_level
            )

            if action_index >= q_table.shape[1]:
                return False, "Q-table action count does not match RL actions.", None

            old_q_value = float(q_table[current_state, action_index])
            next_max_q = float(np.max(q_table[next_state]))
            new_q_value = old_q_value + RL_LEARNING_RATE * (
                reward + (RL_DISCOUNT_FACTOR * next_max_q) - old_q_value
            )
            q_table[current_state, action_index] = new_q_value

        else:
            return False, "Unsupported Q-table structure.", None

        np.save(Q_TABLE_PATH, q_table)

        return True, None, {
            "action": intervention_action,
            "action_index": action_index,
            "reward": reward,
            "old_q_value": round(old_q_value, 6),
            "new_q_value": round(float(new_q_value), 6),
            "learning_rate": RL_LEARNING_RATE,
            "discount_factor": RL_DISCOUNT_FACTOR,
        }

    except Exception as e:
        print("Q-table feedback update error:", str(e))
        return False, f"Q-table update failed: {str(e)}", None


def save_intervention_feedback(
    warning,
    cases_after,
    follow_up_days,
    outcome_status,
    feedback_notes,
    reward,
):
    if supabase_client is None:
        return None, "Supabase is not connected."

    try:
        result = (
            supabase_client.table("intervention_feedback")
            .insert(
                {
                    "warning_history_id": warning["id"],
                    "moh_area_id": warning["moh_area_id"],
                    "phi_officer_id": warning.get("phi_officer_id"),
                    "intervention_action": warning["recommended_action"],
                    "cases_before": warning["dengue_cases"],
                    "cases_after": cases_after,
                    "follow_up_days": follow_up_days,
                    "outcome_status": outcome_status,
                    "feedback_notes": feedback_notes,
                    "reward": reward,
                    "q_table_updated": False,
                }
            )
            .execute()
        )

        if not result.data:
            return None, "Feedback record could not be saved."

        return result.data[0], None

    except Exception as e:
        print("Feedback database save error:", str(e))
        return None, f"Database save failed: {str(e)}"


def mark_feedback_q_table_updated(feedback_id):
    if supabase_client is None:
        return "Supabase is not connected."

    try:
        (
            supabase_client.table("intervention_feedback")
            .update({"q_table_updated": True})
            .eq("id", feedback_id)
            .execute()
        )
        return None

    except Exception as e:
        print("Feedback Q-table status update error:", str(e))
        return f"Could not update feedback status: {str(e)}"


def get_feedback_history_from_db(limit=20):
    if supabase_client is None:
        return None, "Supabase is not connected."

    try:
        result = (
            supabase_client.table("intervention_feedback")
            .select(
                "id, warning_history_id, intervention_action, cases_before, "
                "cases_after, follow_up_days, outcome_status, feedback_notes, "
                "reward, q_table_updated, submitted_at, moh_areas(name), "
                "phi_officers(full_name)"
            )
            .order("submitted_at", desc=True)
            .limit(limit)
            .execute()
        )

        feedback_items = []
        for row in result.data:
            area = row.pop("moh_areas", None) or {}
            officer = row.pop("phi_officers", None) or {}
            row["moh_area_name"] = area.get("name", "Unknown area")
            row["phi_officer_name"] = officer.get("full_name", "Not assigned")
            feedback_items.append(row)

        return feedback_items, None

    except Exception as e:
        print("Feedback history database lookup error:", str(e))
        return None, f"Database lookup failed: {str(e)}"

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
                "/warning-history",
                "/submit-feedback",
                "/feedback-history",
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
@app.route("/warning-history", methods=["GET"])
def warning_history():
    try:
        limit = int(request.args.get("limit", 20))
        limit = max(1, min(limit, 100))
    except ValueError:
        return jsonify(
            {
                "success": False,
                "message": "Limit must be a number.",
            }
        ), 400

    history, database_error = get_warning_history_from_db(limit)

    if database_error:
        return jsonify(
            {
                "success": False,
                "message": database_error,
            }
        ), 500

    return jsonify(
        {
            "success": True,
            "count": len(history),
            "warnings": history,
        }
    )


@app.route("/feedback-history", methods=["GET"])
def feedback_history():
    try:
        limit = int(request.args.get("limit", 20))
        limit = max(1, min(limit, 100))
    except ValueError:
        return jsonify(
            {"success": False, "message": "Limit must be a number."}
        ), 400

    feedback_items, database_error = get_feedback_history_from_db(limit)

    if database_error:
        return jsonify(
            {"success": False, "message": database_error}
        ), 500

    return jsonify(
        {
            "success": True,
            "count": len(feedback_items),
            "feedback": feedback_items,
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


@app.route("/submit-feedback", methods=["POST"])
def submit_feedback():
    """Save a PHI outcome and use it to update the Q-learning table."""
    try:
        data = request.get_json(force=True) or {}

        try:
            warning_history_id = int(data.get("warning_history_id"))
            cases_after = int(data.get("cases_after"))
            follow_up_days = int(data.get("follow_up_days", 14))
        except (TypeError, ValueError):
            return jsonify(
                {
                    "success": False,
                    "message": "warning_history_id, cases_after, and follow_up_days must be valid numbers.",
                }
            ), 400

        outcome_status = str(data.get("outcome_status", "")).strip().lower()
        feedback_notes = str(data.get("feedback_notes", "")).strip()

        if warning_history_id <= 0:
            return jsonify(
                {"success": False, "message": "warning_history_id must be greater than 0."}
            ), 400

        if cases_after < 0:
            return jsonify(
                {"success": False, "message": "cases_after cannot be negative."}
            ), 400

        if follow_up_days <= 0:
            return jsonify(
                {"success": False, "message": "follow_up_days must be greater than 0."}
            ), 400

        if outcome_status not in {"improved", "no_change", "worsened"}:
            return jsonify(
                {
                    "success": False,
                    "message": "outcome_status must be improved, no_change, or worsened.",
                }
            ), 400

        warning, database_error = get_warning_for_feedback(warning_history_id)
        if database_error:
            return jsonify(
                {"success": False, "message": database_error}
            ), 404

        reward = calculate_feedback_reward(
            warning["dengue_cases"],
            cases_after,
            outcome_status,
        )

        feedback, database_error = save_intervention_feedback(
            warning=warning,
            cases_after=cases_after,
            follow_up_days=follow_up_days,
            outcome_status=outcome_status,
            feedback_notes=feedback_notes,
            reward=reward,
        )

        if database_error:
            return jsonify(
                {"success": False, "message": database_error}
            ), 500

        q_updated, q_error, q_update_details = update_q_table_from_feedback(
            cases_before=warning["dengue_cases"],
            cases_after=cases_after,
            rainfall=float(warning["rainfall_mm"]),
            temperature=float(warning["temperature_c"]),
            intervention_action=warning["recommended_action"],
            reward=reward,
        )

        status_update_error = None
        if q_updated:
            status_update_error = mark_feedback_q_table_updated(feedback["id"])
            if status_update_error:
                q_updated = False
                q_error = status_update_error

        return jsonify(
            {
                "success": True,
                "timestamp": current_time(),
                "message": "Feedback saved and processed.",
                "feedback_id": feedback["id"],
                "warning_history_id": warning_history_id,
                "area_id": warning["moh_area_id"],
                "intervention_action": warning["recommended_action"],
                "cases_before": warning["dengue_cases"],
                "cases_after": cases_after,
                "outcome_status": outcome_status,
                "reward": reward,
                "q_table_updated": q_updated,
                "q_table_update": q_update_details,
                "q_table_update_error": q_error,
            }
        ), 201

    except Exception as e:
        print("Submit feedback API error:", str(e))
        return jsonify(
            {
                "success": False,
                "timestamp": current_time(),
                "message": "Feedback API failed.",
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