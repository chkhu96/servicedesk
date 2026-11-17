"""Worker entrypoint: `migrate` (Helm hook Job) or `sla-check` (CronJob)."""
import json
import sys

from common.db import connect, read_secret

SCHEMA = [
    """IF OBJECT_ID('dbo.Engineers') IS NULL
       CREATE TABLE dbo.Engineers (
         Id INT IDENTITY PRIMARY KEY, Name NVARCHAR(100) NOT NULL, Team NVARCHAR(50) NOT NULL)""",
    """IF OBJECT_ID('dbo.Tickets') IS NULL
       CREATE TABLE dbo.Tickets (
         Id INT IDENTITY PRIMARY KEY,
         Title NVARCHAR(200) NOT NULL,
         Description NVARCHAR(MAX) NULL,
         Priority CHAR(2) NOT NULL DEFAULT 'P3',
         Status NVARCHAR(20) NOT NULL DEFAULT 'Open',
         AssigneeId INT NULL REFERENCES dbo.Engineers(Id),
         CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
         ResolvedAt DATETIME2 NULL,
         SlaBreached BIT NOT NULL DEFAULT 0)""",
    """IF OBJECT_ID('dbo.Comments') IS NULL
       CREATE TABLE dbo.Comments (
         Id INT IDENTITY PRIMARY KEY,
         TicketId INT NOT NULL REFERENCES dbo.Tickets(Id),
         Author NVARCHAR(100) NOT NULL,
         Body NVARCHAR(MAX) NOT NULL,
         CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME())""",
]

SEED = [
    """IF NOT EXISTS (SELECT 1 FROM dbo.Engineers)
       INSERT INTO dbo.Engineers (Name, Team) VALUES
       ('Alex Tan','Cloud'),('Priya Nair','Cloud'),('Marcus Lim','Network'),('Siti Rahman','Service Desk')""",
    """IF NOT EXISTS (SELECT 1 FROM dbo.Tickets)
       INSERT INTO dbo.Tickets (Title, Description, Priority, Status, AssigneeId, CreatedAt) VALUES
       ('AVD session host not registering','Host pool shows unavailable','P1','Open',1,DATEADD(HOUR,-6,SYSUTCDATETIME())),
       ('Request new Azure subscription','For dev team','P3','InProgress',2,DATEADD(HOUR,-20,SYSUTCDATETIME())),
       ('VPN tunnel flapping','Site-to-site to DC2','P2','Open',3,DATEADD(HOUR,-3,SYSUTCDATETIME())),
       ('Password reset','User locked out','P4','Open',4,DATEADD(HOUR,-1,SYSUTCDATETIME()))""",
]


def migrate() -> None:
    with connect() as conn:
        for stmt in SCHEMA + SEED:
            conn.execute(stmt)
    print("migration complete")


def sla_check() -> None:
    sla_hours = json.loads(read_secret("sla-config"))  # e.g. {"P1":4,"P2":8,...}
    total = 0
    with connect() as conn:
        for prio, hours in sla_hours.items():
            n = conn.execute(
                """UPDATE dbo.Tickets SET SlaBreached = 1
                   WHERE Priority = ? AND Status IN ('Open','InProgress') AND SlaBreached = 0
                     AND DATEDIFF(MINUTE, CreatedAt, SYSUTCDATETIME()) > ? * 60""",
                prio, int(hours)).rowcount
            total += max(n, 0)
    print(f"sla-check complete, newly breached: {total}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "migrate"
    {"migrate": migrate, "sla-check": sla_check}[cmd]()
