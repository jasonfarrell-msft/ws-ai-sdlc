import azure.functions as func

from function_app import app


def test_fastapi_is_exposed_as_anonymous_function() -> None:
    functions = app.get_functions()
    bindings = [binding.get_dict_repr() for binding in functions[0].get_bindings()]
    trigger = next(binding for binding in bindings if binding["type"] == "httpTrigger")

    assert len(functions) == 1
    assert functions[0].get_function_name() == "http_app_func"
    assert functions[0].get_user_function() is not None
    assert trigger["authLevel"] == func.AuthLevel.ANONYMOUS
    assert trigger["route"] == "/{*route}"
