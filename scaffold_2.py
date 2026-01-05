# generate_scaffold_part2.py
# ---------------------------------------------------------
# Part 2 of 2: Adds the remaining MVP modules to your
# FastAPI backend created by Part 1:
# - schemas: content, qa, projects, events, reports
# - routes:  content, qa, projects, events, notifications, reports
# - optional: docker files, run.sh
# This does NOT overwrite Part-1 core; it only adds files.
# ---------------------------------------------------------
import os, stat
from pathlib import Path
from textwrap import dedent as D

ROOT = Path.cwd() / "backend"

def write(path: Path, content: str, executable: bool=False, skip_if_exists: bool=False):
    if skip_if_exists and path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(D(content).strip() + "\n")
    if executable:
        st = os.stat(path)
        os.chmod(path, st.st_mode | stat.S_IEXEC)

def main():
    # ---- sanity check ----
    if not (ROOT / "app" / "api" / "v1" / "__init__.py").exists():
        raise SystemExit("❌ Part 1 not found. Please run generate_scaffold_part1.py first.")

    # =========================
    # Schemas (remaining)
    # =========================
    write(ROOT / "app/schemas/content.py", """
        from pydantic import BaseModel
        from typing import List, Optional, Any

        class ContentCreate(BaseModel):
            type: str
            title: str
            summary: Optional[str] = None
            body: Optional[str] = None
            evidence: str = "n_a"
            visibility: str = "public"
            sources: Optional[list[Any]] = None
            region: Optional[str] = None
            language: str = "tr"
            tags: Optional[List[str]] = None

        class Content(BaseModel):
            id: str
            author_id: str
            type: str
            title: str
            summary: Optional[str] = None
            body: Optional[str] = None
            evidence: str
            visibility: str
            region: Optional[str] = None
            language: str = "tr"
    """)

    write(ROOT / "app/schemas/qa.py", """
        from pydantic import BaseModel
        from typing import List, Optional, Any

        class QuestionCreate(BaseModel):
            title: str
            body: Optional[str] = None
            tags: List[str] = []
            visibility: str = "public"

        class AnswerCreate(BaseModel):
            question_id: str
            body: str
            evidence: str = "n_a"
            sources: list[Any] = []
    """)

    write(ROOT / "app/schemas/projects.py", """
        from pydantic import BaseModel
        from typing import List, Optional

        class ProjectCreate(BaseModel):
            title: str
            description: Optional[str] = None
            needed_roles: List[str] = []
            region: Optional[str] = None
            tags: List[str] = []
            visibility: str = "public"

        class ProjectApply(BaseModel):
            message: Optional[str] = None
    """)

    write(ROOT / "app/schemas/events.py", """
        from pydantic import BaseModel
        from typing import List, Optional
        from datetime import datetime

        class EventCreate(BaseModel):
            title: str
            description: Optional[str] = None
            type: str  # 'course'|'webinar'|'workshop'
            starts_at: datetime
            ends_at: Optional[datetime] = None
            location: Optional[str] = None
            capacity: Optional[int] = None
            tags: List[str] = []
            visibility: str = "public"
    """)

    write(ROOT / "app/schemas/reports.py", """
        from pydantic import BaseModel

        class ReportCreate(BaseModel):
            entity: str
            entity_id: str
            reason: str | None = None
            severity: int = 1
    """)

    # =========================
    # Routes (new modules)
    # =========================
    # Content
    write(ROOT / "app/api/v1/routes_content.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from typing import Optional
        from ...api.deps import get_db, require_user_id
        from ...schemas.content import ContentCreate
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.post("", response_model=dict)
        async def create_content(payload: ContentCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            csql = text(\"\"\"
                insert into public.content (author_id, type, title, summary, body, evidence, visibility, sources, region, language)
                values (:uid, :type, :title, :summary, :body, :evidence, :visibility, coalesce(:sources,'[]'::jsonb), :region, :language)
                returning id
            \"\"\")
            params = {
                "uid": user_id,
                "type": payload.type, "title": payload.title, "summary": payload.summary, "body": payload.body,
                "evidence": payload.evidence, "visibility": payload.visibility, "sources": payload.sources,
                "region": payload.region, "language": payload.language
            }
            r = await db.execute(csql, params)
            cid = r.scalar()

            if payload.tags:
                # ensure tags exist; insert missing
                await db.execute(text(\"\"\"
                    insert into public.tags (slug, label)
                    select t, initcap(replace(t,'-',' '))
                    from unnest(:tags) as t
                    on conflict do nothing
                \"\"\"), {"tags": payload.tags})
                await db.execute(text(\"\"\"
                    insert into public.content_tags (content_id, tag_id)
                    select :cid, tg.id
                    from public.tags tg
                    where tg.slug = any(:tags)
                \"\"\"), {"cid": cid, "tags": payload.tags})

            await db.commit()
            return {"id": str(cid)}

        @router.get("", response_model=list[dict])
        async def list_content(q: Optional[str] = None, tag: Optional[str] = None, db: AsyncSession = Depends(get_db)):
            base = \"""
                select c.id, c.author_id, c.type, c.title, c.summary, c.visibility, c.region, c.language, c.created_at
                from public.content c
                left join public.content_tags ct on ct.content_id = c.id
                left join public.tags tg on tg.id = ct.tag_id
                where c.is_published = true and (c.visibility = 'public')
            \"
            args = {}
            if q:
                base += " and (c.title ilike :q or c.summary ilike :q or c.body ilike :q)"
                args["q"] = f"%{q}%"
            if tag:
                base += " and tg.slug = :tag"
                args["tag"] = tag
            base += " group by c.id order by c.created_at desc limit 50"
            res = await db.execute(text(base), args)
            return [row_to_dict(r) for r in res.fetchall()]

        @router.get("/{content_id}", response_model=dict)
        async def get_content(content_id: str, db: AsyncSession = Depends(get_db)):
            res = await db.execute(text(\"\"\"
                select c.id, c.author_id, c.type, c.title, c.summary, c.body, c.evidence, c.visibility, c.region, c.language, c.created_at, c.updated_at
                from public.content c where c.id=:id and c.is_published = true
            \"\"\"), {"id": content_id})
            row = res.first()
            if not row:
                return {"error": "Not found"}
            return row_to_dict(row)
    """)

    # Q&A
    write(ROOT / "app/api/v1/routes_qa.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from typing import Optional
        from ...api.deps import get_db, require_user_id
        from ...schemas.qa import QuestionCreate, AnswerCreate
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.post("/questions", response_model=dict)
        async def create_question(payload: QuestionCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.questions (asker_id, title, body, tags, visibility)
                values (:uid, :title, :body, :tags, :visibility)
                returning id
            \"\"\"), {"uid": user_id, "title": payload.title, "body": payload.body, "tags": payload.tags, "visibility": payload.visibility})
            qid = r.scalar()
            await db.commit()
            return {"id": str(qid)}

        @router.get("/questions", response_model=list[dict])
        async def list_questions(q: Optional[str] = None, tag: Optional[str] = None, db: AsyncSession = Depends(get_db)):
            base = "select id, asker_id, title, body, tags, created_at from public.questions where (visibility='public')"
            args = {}
            if q:
                base += " and (title ilike :q or body ilike :q)"
                args["q"] = f"%{q}%"
            if tag:
                base += " and :t = any(tags)"
                args["t"] = tag
            base += " order by created_at desc limit 50"
            res = await db.execute(text(base), args)
            return [row_to_dict(r) for r in res.fetchall()]

        @router.post("/answers", response_model=dict)
        async def create_answer(payload: AnswerCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.answers (question_id, author_id, body, evidence, sources)
                values (:qid, :uid, :body, :evidence, :sources)
                returning id
            \"\"\"), {"qid": payload.question_id, "uid": user_id, "body": payload.body, "evidence": payload.evidence, "sources": payload.sources})
            aid = r.scalar()
            await db.commit()
            return {"id": str(aid)}

        @router.get("/questions/{qid}/answers", response_model=list[dict])
        async def list_answers(qid: str, db: AsyncSession = Depends(get_db)):
            res = await db.execute(text("select id, question_id, author_id, body, is_accepted, created_at from public.answers where question_id=:qid order by created_at asc"), {"qid": qid})
            return [row_to_dict(r) for r in res.fetchall()]
    """)

    # Projects
    write(ROOT / "app/api/v1/routes_projects.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from ...api.deps import get_db, require_user_id
        from ...schemas.projects import ProjectCreate, ProjectApply
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.post("", response_model=dict)
        async def create_project(payload: ProjectCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.projects (owner_id, title, description, needed_roles, region, tags, visibility)
                values (:uid, :title, :description, :needed_roles, :region, :tags, :visibility)
                returning id
            \"\"\"), {"uid": user_id, "title": payload.title, "description": payload.description, "needed_roles": payload.needed_roles, "region": payload.region, "tags": payload.tags, "visibility": payload.visibility})
            pid = r.scalar()
            await db.execute(text("insert into public.project_members (project_id, user_id, role) values (:pid, :uid, 'owner') on conflict do nothing"), {"pid": pid, "uid": user_id})
            await db.commit()
            return {"id": str(pid)}

        @router.get("", response_model=list[dict])
        async def list_projects(db: AsyncSession = Depends(get_db)):
            res = await db.execute(text("select id, owner_id, title, description, needed_roles, tags, created_at from public.projects order by created_at desc limit 50"))
            return [row_to_dict(r) for r in res.fetchall()]

        @router.post("/{project_id}/apply", response_model=dict)
        async def apply_project(project_id: str, payload: ProjectApply, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.project_applications (project_id, applicant_id, message)
                values (:pid, :uid, :msg) returning id
            \"\"\"), {"pid": project_id, "uid": user_id, "msg": payload.message})
            aid = r.scalar()
            await db.commit()
            return {"application_id": str(aid)}
    """)

    # Events
    write(ROOT / "app/api/v1/routes_events.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from ...api.deps import get_db, require_user_id
        from ...schemas.events import EventCreate
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.post("", response_model=dict)
        async def create_event(payload: EventCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.events (host_id, title, description, type, starts_at, ends_at, location, capacity, tags, visibility)
                values (:uid, :title, :description, :type, :starts_at, :ends_at, :location, :capacity, :tags, :visibility)
                returning id
            \"\"\"), {"uid": user_id, **payload.model_dump()})
            eid = r.scalar()
            await db.commit()
            return {"id": str(eid)}

        @router.get("", response_model=list[dict])
        async def list_events(db: AsyncSession = Depends(get_db)):
            res = await db.execute(text("select id, host_id, title, type, starts_at, ends_at, location, tags, created_at from public.events order by starts_at asc limit 50"))
            return [row_to_dict(r) for r in res.fetchall()]

        @router.post("/{event_id}/enroll", response_model=dict)
        async def enroll_event(event_id: str, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            await db.execute(text(\"\"\"
                insert into public.event_enrollments (event_id, user_id, status)
                values (:eid, :uid, 'going')
                on conflict do nothing
            \"\"\"), {"eid": event_id, "uid": user_id})
            await db.commit()
            return {"enrolled": True}
    """)

    # Notifications
    write(ROOT / "app/api/v1/routes_notifications.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from ...api.deps import get_db, require_user_id
        from ...utils.dbhelpers import row_to_dict

        router = APIRouter()

        @router.get("", response_model=list[dict])
        async def my_notifications(db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            res = await db.execute(text("select id, type, payload, read_at, created_at from public.notifications where user_id=:uid order by created_at desc limit 100"), {"uid": user_id})
            return [row_to_dict(r) for r in res.fetchall()]
    """)

    # Reports
    write(ROOT / "app/api/v1/routes_reports.py", """
        from fastapi import APIRouter, Depends
        from sqlalchemy import text
        from sqlalchemy.ext.asyncio import AsyncSession
        from ...api.deps import get_db, require_user_id
        from ...schemas.reports import ReportCreate

        router = APIRouter()

        @router.post("", response_model=dict)
        async def create_report(payload: ReportCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
            r = await db.execute(text(\"\"\"
                insert into public.reports (reporter_id, entity, entity_id, reason, severity)
                values (:uid, :entity, :eid, :reason, :severity) returning id
            \"\"\"), {"uid": user_id, "entity": payload.entity, "eid": payload.entity_id, "reason": payload.reason, "severity": payload.severity})
            rid = r.scalar()
            await db.commit()
            return {"id": str(rid)}
    """)

    # =========================
    # Optional tooling
    # =========================
    write(ROOT / "run.sh", """
        #!/usr/bin/env bash
        set -e
        . .venv/bin/activate || source .venv/bin/activate
        exec uvicorn app.main:app --host 0.0.0.0 --port 8000
    """, executable=True, skip_if_exists=True)

    write(ROOT / "docker/Dockerfile", """
        FROM python:3.11-slim
        ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
        WORKDIR /app
        COPY requirements.txt .
        RUN pip install --no-cache-dir -r requirements.txt
        COPY app ./app
        EXPOSE 8000
        CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
    """, skip_if_exists=True)

    write(ROOT / "docker/docker-compose.yml", """
        version: "3.9"
        services:
          api:
            build:
              context: ..
              dockerfile: docker/Dockerfile
            env_file:
              - ../.env
            ports:
              - "8000:8000"
    """, skip_if_exists=True)

    print("✅ Scaffold Part 2 files added under:", ROOT)
    print("   New tags available in /api/docs: content, qa, projects, events, notifications, reports")

if __name__ == "__main__":
    main()