import os

from fastapi import FastAPI, Response

from common.db import connect, rows_to_dicts, schema_ready

app = FastAPI(title="report-api")
VERSION = os.getenv("APP_VERSION", "v1")  # used later for v1/v2 weighted-routing exercise


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response):
    if not schema_ready():
        response.status_code = 503
        return {"status": "waiting-for-schema"}
    return {"status": "ready"}


@app.get("/api/reports/summary")
def summary():
    with connect() as conn:
        by_status = rows_to_dicts(conn.execute(
            "SELECT Status, COUNT(*) AS Count FROM dbo.Tickets GROUP BY Status"))
        open_by_priority = rows_to_dicts(conn.execute(
            """SELECT Priority, COUNT(*) AS Count FROM dbo.Tickets
               WHERE Status IN ('Open','InProgress') GROUP BY Priority ORDER BY Priority"""))
        mttr = conn.execute(
            """SELECT AVG(CAST(DATEDIFF(MINUTE, CreatedAt, ResolvedAt) AS FLOAT)) / 60.0
               FROM dbo.Tickets WHERE ResolvedAt IS NOT NULL""").fetchone()[0]
        breached = conn.execute(
            "SELECT COUNT(*) FROM dbo.Tickets WHERE SlaBreached = 1 AND Status IN ('Open','InProgress')"
        ).fetchone()[0]
    return {
        "version": VERSION,
        "byStatus": by_status,
        "openByPriority": open_by_priority,
        "meanTimeToResolveHours": round(mttr, 2) if mttr is not None else None,
        "openSlaBreaches": breached,
    }


@app.get("/api/reports/workload")
def workload():
    with connect() as conn:
        return rows_to_dicts(conn.execute(
            """SELECT e.Name, e.Team, COUNT(t.Id) AS OpenTickets
               FROM dbo.Engineers e
               LEFT JOIN dbo.Tickets t ON t.AssigneeId = e.Id AND t.Status IN ('Open','InProgress')
               GROUP BY e.Name, e.Team ORDER BY OpenTickets DESC"""))
