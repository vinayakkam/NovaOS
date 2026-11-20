# Sourced by startplasma for every Plasma session.
# glibc creates one malloc arena per thread by default; Qt/KDE apps are heavily
# threaded, so freed memory stays pinned in many arenas. Two arenas keeps RSS of
# plasmashell, kwin and friends noticeably lower at no visible cost.
export MALLOC_ARENA_MAX=2
