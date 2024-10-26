import numpy as np

from pymoo.algorithms.moo.nsga3 import NSGA3
from pymoo.problems import get_problem
from pymoo.util.ref_dirs import get_reference_directions
from pymoo.optimize import minimize
from pymoo.util.display.column import Column
from pymoo.util.display.output import Output

ref_dirs = get_reference_directions("das-dennis", 2, n_partitions=12)

[print(i[1]/i[0]) for i in ref_dirs]

class MyOutput(Output):

    def __init__(self):
        super().__init__()
        self.x_mean = Column("x_mean", width=13)
        self.x_std = Column("x_std", width=13)
        self.columns += [self.x_mean, self.x_std]

    def update(self, algorithm):
        super().update(algorithm)
        self.x_mean.set(np.mean(algorithm.pop.get("X")))
        self.x_std.set(np.std(algorithm.pop.get("X")))

ref = ref_dre
problem = get_problem("zdt2")

algorithm = NSGA3(pop_size=5, )

res = minimize(problem,
               algorithm,
               ('n_gen', 5),
               seed=1,
               output=MyOutput(),
               verbose=True)