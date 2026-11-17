from datetime import datetime, timezone
from typing import Literal, Optional

from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel

from common.db import connect, rows_to_dicts, schema_ready

app = FastAPI(title="ticket-api", root_path="")

Priority = Literal["P1", "P2", "P3", "P4"]
Status = Literal["Open", "InProgress", "Resolved", "Closed"]


class TicketIn(BaseModel):
    title: str
    description: str = ""
    priority: Priority = "P3"


class TicketUpdate(BaseModel):
    status: Optional[Status] = None
    assigneeId: Optional[int] = None
    priority: Optional[Priority] = None


class CommentIn(BaseModel):
    author: str
    body: str


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/readyz")
def readyz(response: Response):
    if not schema_ready():
        response.status_code = 503
        return {"status": "waiting-for-schema"}
    return {"status": "ready"}


@app.get("/api/tickets")
def list_tickets(status: Optional[Status] = None):
    sql = """SELECT t.Id, t.Title, t.Priority, t.Status, e.Name AS Assignee,
                    t.CreatedAt, t.ResolvedAt, t.SlaBreached
             FROM dbo.Tickets t LEFT JOIN dbo.Engineers e ON e.Id = t.AssigneeId"""
    params: list = []
    if status:
        sql += " WHERE t.Status = ?"
        params.append(status)
    sql += " ORDER BY t.CreatedAt DESC"
    with connect() as conn:
        return rows_to_dicts(conn.execute(sql, params))


@app.get("/api/tickets/engineers")
def list_engineers():
    with connect() as conn:
        return rows_to_dicts(conn.execute("SELECT Id, Name, Team FROM dbo.Engineers ORDER BY Name"))


@app.get("/api/tickets/{ticket_id}")
def get_ticket(ticket_id: int):
    with connect() as conn:
        t = rows_to_dicts(conn.execute("SELECT * FROM dbo.Tickets WHERE Id = ?", ticket_id))
        if not t:
            raise HTTPException(404, "ticket not found")
        c = rows_to_dicts(conn.execute(
            "SELECT Id, Author, Body, CreatedAt FROM dbo.Comments WHERE TicketId = ? ORDER BY CreatedAt",
            ticket_id))
    return {**t[0], "comments": c}


@app.post("/api/tickets", status_code=201)
def create_ticket(body: TicketIn):
    with connect() as conn:
        row = conn.execute(
            "INSERT INTO dbo.Tickets (Title, Description, Priority) OUTPUT INSERTED.Id VALUES (?, ?, ?)",
            body.title, body.description, body.priority).fetchone()
    return {"id": row[0]}


@app.patch("/api/tickets/{ticket_id}")
def update_ticket(ticket_id: int, body: TicketUpdate):
    sets, params = [], []
    if body.status:
        sets.append("Status = ?")
        params.append(body.status)
        if body.status in ("Resolved", "Closed"):
            sets.append("ResolvedAt = ?")
            params.append(datetime.now(timezone.utc).replace(tzinfo=None))
    if body.assigneeId is not None:
        sets.append("AssigneeId = ?")
        params.append(body.assigneeId)
    if body.priority:
        sets.append("Priority = ?")
        params.append(body.priority)
    if not sets:
        raise HTTPException(400, "nothing to update")
    with connect() as conn:
        n = conn.execute(f"UPDATE dbo.Tickets SET {', '.join(sets)} WHERE Id = ?", *params, ticket_id).rowcount
    if n == 0:
        raise HTTPException(404, "ticket not found")
    return {"updated": ticket_id}


@app.post("/api/tickets/{ticket_id}/comments", status_code=201)
def add_comment(ticket_id: int, body: CommentIn):
    with connect() as conn:
        conn.execute("INSERT INTO dbo.Comments (TicketId, Author, Body) VALUES (?, ?, ?)",
                     ticket_id, body.author, body.body)
    return {"ticketId": ticket_id}
