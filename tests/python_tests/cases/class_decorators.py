class X:
    @staticmethod
    def util(a, b):
        return a * b

print(X.util(3, 4))

class Y:
    count = 0
    @classmethod
    def get_count(cls):
        return cls.count

print(Y.get_count())

class Z:
    def __init__(self, val):
        self._val = val
    @property
    def val(self):
        return self._val

z = Z(42)
print(z.val)
