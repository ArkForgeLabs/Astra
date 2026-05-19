squares = [x * x for x in range(5)]
for v in squares:
    print(v)

evens = [x for x in range(10) if x % 2 == 0]
for v in evens:
    print(v)

pairs = [[i, j] for i in range(3) for j in range(2)]
for p in pairs:
    print(p[0])
    print(p[1])
