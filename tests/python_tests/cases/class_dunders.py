class X:
    def __init__(self, val):
        self.val = val
    def __str__(self):
        return str(self.val)
    def __len__(self):
        return self.val
    def __add__(self, other):
        return X(self.val + other.val)
    def __eq__(self, other):
        return self.val == other.val

x = X(5)
y = X(3)
print(str(x))
print(len(x))
z = x + y
print(z.val)
print(x == y)
print(x == X(5))
