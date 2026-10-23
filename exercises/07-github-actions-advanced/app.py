"""Tiny greeting app used by the advanced CI exercise."""


def greet(name):
    """Return a greeting for name, defaulting to 'world' for blank input."""
    name = (name or "").strip()
    return f"Hello, {name or 'world'}!"


if __name__ == "__main__":
    print(greet("Actions"))
