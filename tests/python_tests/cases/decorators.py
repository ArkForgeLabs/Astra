def deco(fn):
    return lambda: 42

@deco
def foo():
    return 0

print(foo())

def make_deco(n):
    def wrap(fn):
        return lambda *a: fn(*a) * n
    return wrap

@make_deco(2)
@make_deco(3)
def compute(x, y):
    return x + y

print(compute(5, 1))
