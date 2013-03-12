import os
import scipy.stats
from scipy.optimize import brentq
import numpy as np
if __name__ == "__main__":
    # Must happen before import pyplot
    import matplotlib
    matplotlib.use("PDF")
import matplotlib.pyplot as plt

class Truncate(object):
    def __init__(self, dist, low, high):
        self._dist = dist
        self._low = low
        self._high = high
        # Normalizing constant (partition function) for the truncated
        # distribution
        self._Z = self._dist.cdf(high) - self._dist.cdf(low)

    def rvs(self, count):
        out = np.empty(count)
        misses = np.ones(count, dtype=bool)
        while np.any(misses):
            out[misses] = self._dist.rvs(np.sum(misses))
            misses = ((out < self._low) | (out > self._high))
        return out

    def pdf(self, x):
        # Annoying dance to make the in-place assignments work even when x is
        # a scalar:
        x = np.asarray(x)
        orig_shape = x.shape
        x = np.atleast_1d(x)
        pdf = self._dist.pdf(x)
        pdf[x < self._low] = 0
        pdf[x > self._high] = 0
        pdf /= self._Z
        return pdf.reshape(orig_shape)

    def sf(self, x):
        # Annoying dance to make the in-place assignments work even when x is
        # a scalar:
        x = np.asarray(x)
        orig_shape = x.shape
        x = np.atleast_1d(x)
        sf = self._dist.sf(x)
        # The survival function is 0 at self._high
        sf -= self._dist.sf(self._high)
        # And 1 at self._low
        sf /= self._dist.sf(self._low)
        # And out-of-range values of course
        sf[x < self._low] = 1
        sf[x > self._high] = 0
        return sf.reshape(orig_shape)

    def cdf(self, x):
        return 1 - self.sf(x)

def hazard(dist, x):
    # P(X = x | X >= x)
    # this is an infinitesmal (i.e., density), with unbounded range
    return dist.pdf(x) / dist.sf(x)

def local_hazard(dist, x, dx):
    # P(x + dx > X >= x | X >= x)
    # The non-infinitesmal version of the above; always in [0, 1]
    return (dist.cdf(x + dx) - dist.cdf(x)) / dist.sf(x)

def hazard_dist(dist, samples=10000):
    rvs = dist.rvs(samples)
    return hazard(dist, rvs)

def local_hazard_dist(dist, dx, samples=10000):
    rvs = dist.rvs(samples)
    return local_hazard(dist, rvs, dx)

# def semilogx_hist(ax, data, num_bins=10, range=None):
#     if range is None:
#         range = [data.min(), data.max()]
#     h = ax.hist(data, bins=np.logspace(np.log10(range[0]),
#                                        np.log10(range[1]),
#                                        num_bins))
#     ax.set_xscale("log")
#     return h

def plot_dist(name, dist, low, high):
    low = brentq(lambda x: dist.sf(x) - (1-1e-5), -1000, 1000)
    high = brentq(lambda x: dist.sf(x) - 1e-5, -1000, 1000)
    span = (high - low)
    f = plt.figure()
    f.set_figwidth(8.2)
    f.set_figheight(11.6)
    f.suptitle(name)
    # pdf, sf, raw hazard, local hazard at 0.01
    x = np.linspace(low, high, 1000)
    s1 = f.add_subplot(4, 4, 1)
    s1.set_title("pdf")
    s1.plot(x, dist.pdf(x))
    f.add_subplot(4, 4, 5).semilogy(x, dist.pdf(x))
    s2 = f.add_subplot(4, 4, 2)
    s2.set_title("survival")
    s2.plot(x, dist.sf(x))
    f.add_subplot(4, 4, 6).semilogy(x, dist.sf(x))
    s3 = f.add_subplot(4, 4, 3)
    s3.set_title("hazard")
    s3.plot(x, hazard(dist, x))
    f.add_subplot(4, 4, 7).semilogy(x, hazard(dist, x))
    s4 = f.add_subplot(4, 4, 4)
    s4.set_title("lochaz(0.01*span)")
    s4.plot(x, local_hazard(dist, x, 0.01 * span))
    f.add_subplot(4, 4, 8).semilogy(x, local_hazard(dist, x, 0.01 * span))
    # raw hazard dist, local hazard dist at 0.1, 0.01, 0.001
    # and ditto with log-space x axis
    s9 = f.add_subplot(4, 4, 9)
    s9.set_title("hazdist")
    d = hazard_dist(dist)
    s9.hist(d, 100)
    s13 = f.add_subplot(4, 4, 13)
    s13.hist(np.log10(d), 100)
    for i, delta in zip(xrange(10, 13), [0.1, 0.01, 0.001]):
        s = f.add_subplot(4, 4, i)
        s.set_title("lochazdist(%s*span)" % (delta,))
        d = local_hazard_dist(dist, delta * span)
        s.hist(d, 100, range=[0, 1])
        s_low = f.add_subplot(4, 4, i + 4)
        (counts, _, _) = s_low.hist(np.log10(d), 100, range=[-5, 0])
        if delta == 0.001:
            print "  bins >100 lochazdist(0.001) in log space: %s" % (
                np.sum(counts > 100))
    return f

DISTS = [
    # commented out terrible ones
    ("uniform", scipy.stats.uniform(), 0, 1),
    ("beta(1.5, 1)", scipy.stats.beta(1.5, 1), 0, 1),
    ("beta(2, 1)", scipy.stats.beta(2, 1), 0, 1),
    # PDF explodes:
    #("beta(2, 0.5)", scipy.stats.beta(2, 0.5), 0, 1),
    #("beta(1, 0.5)", scipy.stats.beta(1, 0.5), 0, 1),
    ("beta(3, 1)", scipy.stats.beta(3, 1), 0, 1),
    ("beta(2, 1.5)", scipy.stats.beta(2, 1.5), 0, 1),
    ("beta(3, 2)", scipy.stats.beta(3, 2), 0, 1),
    #("beta(1, 2)", scipy.stats.beta(1, 2), 0, 1),
    #("beta(0.5, 0.5)", scipy.stats.beta(0.5, 0.5), 1e-6, 1-1e-6),
    ("beta(2, 2)", scipy.stats.beta(2, 2), 0, 1),
    ("beta(5, 5)", scipy.stats.beta(5, 5), 0, 1),
    ("beta(10, 10)", scipy.stats.beta(10, 10), 0, 1),
    # https://en.wikipedia.org/wiki/File:Gamma_distribution_pdf.svg
    # This is the exponential distribution...
    #("gamma(1, 2)", scipy.stats.gamma(1, scale=2), 0, 14),
    # These have hazard functions that start out going straight up
    # ("gamma(2, 2)", scipy.stats.gamma(2, scale=2), 0, 20),
    # ("gamma(3, 2)", scipy.stats.gamma(3, scale=2), 0, 14),
    # ("gamma(5, 1)", scipy.stats.gamma(5, scale=1), 0, 14),
    # ("logistic", scipy.stats.logistic(), -10, 10),
    # ("trunc logistic (-5, 5)", Truncate(scipy.stats.logistic(), -5, 5), -6, 6),
    # ("trunc logistic (-10, 10)", Truncate(scipy.stats.logistic(), -10, 10), -11, 11),
    #("trunc logistic (0, 5)", Truncate(scipy.stats.logistic(), 0, 5), -1, 6),
    #("trunc logistic (0, 9)", Truncate(scipy.stats.logistic(), 0, 9), -1, 10),

    # - Everyone knows what it is (readers and participants)
    # - no sharp changes or singularities in hazard - just smoothly increases
    ("full normal (trunc to (-5, 5) is practically equiv)", scipy.stats.norm(), -5, 5),

    #("trunc normal (-5, 5) (equiv to full normal)", Truncate(scipy.stats.norm(), -5, 5), -6, 6),
    #("trunc normal (-8, 8)", Truncate(scipy.stats.norm(), -8, 8), -9, 9),
    #("trunc normal (0, 5)", Truncate(scipy.stats.norm(), 0, 5), -1, 6),
    #("trunc normal (-5, 9)", Truncate(scipy.stats.norm(), -5, 9), -6, 10),
    #("trunc normal (0, 9)", Truncate(scipy.stats.norm(), 0, 9), -1, 10),

    ("weibull(2) (= rayleigh)", scipy.stats.exponweib(1, 2), -1, 10),
    ("weibull(3)", scipy.stats.exponweib(1, 3), -1, 10),
    # *extremely* heavy-tailed...
    #("weibull(0.5)", scipy.stats.exponweib(1, 0.5), -1, 10),

    # Hazard starts positive
    #("exponweib(2, 0.5)", scipy.stats.exponweib(2, 0.5), -1, 10),
    # Hazard starts going straight up
    #("exponweib(2, 1)", scipy.stats.exponweib(2, 1), -1, 10),
    # Basically a slightly distorted weibull(2); no advantage and harder to
    # explain:
    #("exponweib(2, 2)", scipy.stats.exponweib(2, 2), -1, 10),
    # Indistinguishable from weibull(3):
    #("exponweib(2, 3)", scipy.stats.exponweib(2, 3), -1, 10),
    # Hazard starts high for these three:
    # ("exponweib(0.5, 0.5)", scipy.stats.exponweib(0.5, 0.5), -1, 10),
    # ("exponweib(0.5, 1)", scipy.stats.exponweib(0.5, 1), -1, 10),
    # ("exponweib(0.5, 2)", scipy.stats.exponweib(0.5, 2), -1, 10),
    # Basically a slightly distorted version of weibull(3); no advantage and
    # harder to explain:
    #("exponweib(0.5, 3)", scipy.stats.exponweib(0.5, 3), -1, 10),

    # These hazards are okay, but just complicated for no good reason, making
    # them harder to explain (and probably for participants to estimate):
    ("gamma(9, 0.5)", scipy.stats.gamma(9, scale=0.5), 0, 14),
    ("trunc logistic (-5, 10)", Truncate(scipy.stats.logistic(), -5, 10), -6, 11),
    ]

def plotall():
    # http://matplotlib.org/faq/howto_faq.html#save-multiple-plots-to-one-pdf-file
    matplotlib.rcParams.update({"font.size": 8})
    from matplotlib.backends.backend_pdf import PdfPages
    os.unlink("all-hazards.pdf")
    pp = PdfPages("all-hazards.pdf")
    for (name, dist, low, high) in DISTS:
        print name
        try:
            f = plot_dist(name, dist, low, high)
            f.savefig(pp, format="pdf")
        except Exception, e:
            import pdb; pdb.post_mortem()
            print (name, dist, low, high), "->", e
    pp.close()

if __name__ == "__main__":
    plotall()
