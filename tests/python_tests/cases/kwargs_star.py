def merge(*args):
    total = 0
    for v in args:
        total = total + v
    return total

print(merge(1, 2, 3, 4, 5))
print(merge(10, 20))

def collect(**kwargs):
    return len(kwargs)

print(collect(a=1, b=2, c=3))
