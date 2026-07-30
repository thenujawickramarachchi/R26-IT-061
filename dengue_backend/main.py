import os
from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from models.schemas import ChatRequest, ClaimRequest, SimulationRequest
from services.chatbot_service import generate_chatbot_response
from services.misinformation_service import check_misinformation
from services.report_service import generate_weekly_report, analyze_uploaded_report
from services.simulator_service import simulate_counterfactual_risk

app = FastAPI(title="Dengue AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", response_class=HTMLResponse)
def home():
    return """
<!DOCTYPE html>
<html>
<head>
    <title>Dengue AI Backend</title>
    <style>
        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #fdf7ff;
            color: #17142A;
        }

        .layout {
            display: flex;
            min-height: 100vh;
        }

        .sidebar {
            width: 250px;
            background: white;
            border-right: 1px solid #eee;
            padding: 25px;
        }

        .logo {
            font-size: 24px;
            font-weight: bold;
            color: #6D35F4;
            margin-bottom: 40px;
        }

        .nav-item {
            padding: 14px 16px;
            border-radius: 14px;
            margin-bottom: 10px;
            color: #333;
            font-weight: 600;
        }

        .nav-item.active {
            background: #efe7ff;
            color: #6D35F4;
        }

        .main {
            flex: 1;
            padding: 35px;
        }

        .topbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .status {
            background: #dcfce7;
            color: #15803d;
            padding: 10px 18px;
            border-radius: 20px;
            font-weight: bold;
        }

        h1 {
            font-size: 34px;
            margin-bottom: 5px;
        }

        .subtitle {
            color: #666;
            margin-bottom: 30px;
        }

        .cards {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 18px;
            margin-bottom: 25px;
        }

        .card {
            background: white;
            padding: 24px;
            border-radius: 20px;
            box-shadow: 0 10px 25px rgba(109, 53, 244, 0.08);
            border: 1px solid #eee;
        }

        .card h3 {
            margin: 0;
            font-size: 15px;
            color: #555;
        }

        .card .number {
            font-size: 32px;
            font-weight: bold;
            margin-top: 10px;
        }

        .green { color: #16a34a; }
        .purple { color: #6D35F4; }
        .orange { color: #f97316; }
        .blue { color: #2563eb; }

        .content-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 22px;
        }

        .activity {
            margin-top: 18px;
            padding: 14px 0;
            border-bottom: 1px solid #eee;
        }

        .activity-title {
            font-weight: bold;
        }

        .activity-text {
            color: #666;
            font-size: 14px;
            margin-top: 4px;
        }

        .endpoint {
            display: flex;
            justify-content: space-between;
            background: #f7f4ff;
            padding: 12px 14px;
            border-radius: 12px;
            margin-top: 10px;
        }

        .method {
            font-weight: bold;
            color: white;
            background: #6D35F4;
            padding: 4px 10px;
            border-radius: 8px;
            margin-right: 10px;
        }

        .footer {
            margin-top: 35px;
            color: #777;
            font-size: 14px;
        }

        @media(max-width: 900px) {
            .cards {
                grid-template-columns: 1fr 1fr;
            }
            .content-grid {
                grid-template-columns: 1fr;
            }
            .sidebar {
                display: none;
            }
        }
    </style>
</head>
<body>
    <div class="layout">

        <div class="sidebar">
            <div class="logo">🦟 Dengue AI Backend</div>

            <div class="nav-item active">Dashboard</div>
            <div class="nav-item">AI Chatbot</div>
            <div class="nav-item">Report Analysis</div>
            <div class="nav-item">Misinformation Check</div>
            <div class="nav-item">Risk Simulator</div>

            <br><br>

            <div class="card">
                <h3>API Status</h3>
                <div class="number green" style="font-size:22px;">Running</div>
                <p>FastAPI Server</p>
                <p>Version 1.0.0</p>
            </div>
        </div>

        <div class="main">
            <div class="topbar">
                <div>
                    <h1>Welcome to Dengue AI Backend</h1>
                    <div class="subtitle">AI Powered Dengue Surveillance and Intelligence System</div>
                </div>
                <div class="status">● System Online</div>
            </div>

            <div class="cards">
                <div class="card">
                    <h3>Total Chat Queries</h3>
                    <div class="number purple">23</div>
                    <p class="purple">+12% this week</p>
                </div>

                <div class="card">
                    <h3>Reports Analyzed</h3>
                    <div class="number green">15</div>
                    <p class="green">+8% this week</p>
                </div>

                <div class="card">
                    <h3>Misinformation Checks</h3>
                    <div class="number orange">18</div>
                    <p class="orange">+15% this week</p>
                </div>

                <div class="card">
                    <h3>Simulations Run</h3>
                    <div class="number blue">11</div>
                    <p class="blue">+10% this week</p>
                </div>
            </div>

            <div class="content-grid">
                <div class="card">
                    <h2>Recent Activity</h2>

                    <div class="activity">
                        <div class="activity-title">Chat query processed</div>
                        <div class="activity-text">What are dengue symptoms in Colombo this week?</div>
                    </div>

                    <div class="activity">
                        <div class="activity-title">Report analyzed</div>
                        <div class="activity-text">dengue_report_april.txt</div>
                    </div>

                    <div class="activity">
                        <div class="activity-title">Misinformation check</div>
                        <div class="activity-text">Papaya leaf can cure dengue instantly</div>
                    </div>

                    <div class="activity">
                        <div class="activity-title">Risk simulation completed</div>
                        <div class="activity-text">Rainfall +30mm, Humidity +5%</div>
                    </div>
                </div>

                <div>
                    <div class="card">
                        <h2>System Overview</h2>
                        <p><b>Backend Status:</b> <span class="green">Online</span></p>
                        <p><b>Machine Learning Model:</b> Loaded</p>
                        <p><b>Model Type:</b> Random Forest</p>
                        <p><b>Risk Levels:</b> Low / Medium / High</p>
                    </div>

                    <br>

                    <div class="card">
                        <h2>API Endpoints</h2>

                        <div class="endpoint">
                            <span><span class="method">POST</span>/chat</span>
                            <span>AI Chatbot</span>
                        </div>

                        <div class="endpoint">
                            <span><span class="method">POST</span>/upload-report</span>
                            <span>Report Analysis</span>
                        </div>

                        <div class="endpoint">
                            <span><span class="method">POST</span>/check-misinformation</span>
                            <span>Misinformation</span>
                        </div>

                        <div class="endpoint">
                            <span><span class="method">POST</span>/simulate-risk</span>
                            <span>Risk Simulator</span>
                        </div>
                    </div>
                </div>
            </div>

            <div class="footer">
                Dengue AI Backend System • Built with FastAPI
            </div>
        </div>
    </div>
</body>
</html>
"""

@app.post("/chat")
def chat(request: ChatRequest):
    return generate_chatbot_response(request.message)

@app.post("/check-misinformation")
def misinformation(request: ClaimRequest):
    return check_misinformation(request.claim)

@app.post("/generate-report")
def report():
    result = generate_weekly_report()
    return {"report": result}

@app.post("/upload-report")
async def upload_report(file: UploadFile = File(...)):
    os.makedirs("uploads", exist_ok=True)
    file_path = os.path.join("uploads", file.filename)

    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())

    result = analyze_uploaded_report(file_path)

    return {
        "message": "File uploaded and analyzed successfully",
        "filename": file.filename,
        "analysis": result
    }

@app.post("/simulate-risk")
def simulate_risk(request: SimulationRequest):
    return simulate_counterfactual_risk(request)
