def add(a, b):
    return a + b

print(add(3, 4))

def fact(n):
    if n == 0:
        return 1
    return n * fact(n - 1)

print(fact(5))

def make_multiplier(n):
    def mul(x):
        return x * n
    return mul

double = make_multiplier(2)
print(double(10))

def identity(x):
    return x

print(identity(42))
