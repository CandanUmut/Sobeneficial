from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from ...api.deps import get_db, require_user_id
from ...schemas.projects import ProjectCreate, ProjectApply
from ...utils.dbhelpers import row_to_dict

router = APIRouter()

@router.post("", response_model=dict)
async def create_project(payload: ProjectCreate, db: AsyncSession = Depends(get_db), user_id: str = Depends(require_user_id)):
    r = await db.execute(text("""
        insert into public.projects (owner_id, title, description, needed_roles, region, tags, visibility)
        values (:uid, :title, :description, :needed_roles, :region, :tags, :visibility)
        returning id
    """), {"uid": user_id, "title": payload.title, "description": payload.description, "needed_roles": payload.needed_roles, "region": payload.region, "tags": payload.tags, "visibility": payload.visibility})
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
    r = await db.execute(text("""
        insert into public.project_applications (project_id, applicant_id, message)
        values (:pid, :uid, :msg) returning id
    """), {"pid": project_id, "uid": user_id, "msg": payload.message})
    aid = r.scalar()
    await db.commit()
    return {"application_id": str(aid)}
