from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

TicketStatus = Literal["open", "pending", "resolved", "closed"]
TicketPriority = Literal["low", "medium", "high", "urgent"]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class CreateTicket(StrictModel):
    subject: str = Field(min_length=4, max_length=120)
    description: str = Field(min_length=10, max_length=4000)
    priority: TicketPriority
    product: str = Field(min_length=2, max_length=60)


class ChangeStatus(StrictModel):
    status: TicketStatus


class TicketFilters(StrictModel):
    status: TicketStatus | None = None
    priority: TicketPriority | None = None
    product: str | None = Field(default=None, min_length=1, max_length=60)
    search: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("product", "search", mode="before")
    @classmethod
    def reject_blank(cls, value: object) -> object:
        if isinstance(value, str) and not value.strip():
            raise ValueError("must not be blank")
        return value


class ArticleFilters(StrictModel):
    search: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("search", mode="before")
    @classmethod
    def reject_blank(cls, value: object) -> object:
        if isinstance(value, str) and not value.strip():
            raise ValueError("must not be blank")
        return value
