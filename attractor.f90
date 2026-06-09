! attractor.f90
!
! ForTRANart core: a four-model strange attractor integrator
! (Lorenz-63, Aizawa, Thomas, Halvorsen) by classical RK4.
! Compiled to wasm32 via LFortran for execution in a browser.
!
! Model dispatch happens inside deriv via a select case on model_id.
! Parameters are stored in a generic pars(8) array; the JS side holds
! the mapping from each model's parameter names to indices.
!
! Exposed C-bound entry points:
!   get_buffer_address  -> c_ptr   linear-memory pointer to output buffer
!   get_buffer_capacity -> i32     number of doubles in the buffer
!   set_model(m)                   pick 0..3 (0=Lorenz, 1=Aizawa,
!                                              2=Thomas, 3=Halvorsen)
!   set_param(idx, val)            set pars(idx+1)  (0-indexed for JS)
!   set_dt(h)                      integration step
!   reset_state(x0, y0, z0)        seed the trajectory
!   integrate(n_steps)             advance and fill the buffer
!
! Buffer layout: contiguous [x0, y0, z0, x1, y1, z1, ...] as IEEE 754 doubles.
!
! Structural note: the C-bound entry points live in a module (attractor_core)
! rather than in the contains section of a main program. The Fortran standard
! forbids BIND(C, NAME="...") on internal procedures (those inside a program's
! contains), so they must be module or external procedures. This file
! contains only modules; the wasm build links with --no-entry (no main is
! needed), and the native test build supplies its own program in test_driver.f90.

module attractor_state
  use, intrinsic :: iso_c_binding
  implicit none

  integer, parameter :: BUF_DOUBLES = 30000
  integer, parameter :: N_PARS      = 8

  integer(c_int), save :: model_id = 0

  real(c_double), target, save :: buffer(BUF_DOUBLES)

  real(c_double), save :: sx = 0.1_c_double
  real(c_double), save :: sy = 0.0_c_double
  real(c_double), save :: sz = 0.0_c_double

  real(c_double), save :: pars(N_PARS)
  real(c_double), save :: par_dt = 0.005_c_double
end module attractor_state


module attractor_core
  use, intrinsic :: iso_c_binding
  use attractor_state
  implicit none

  private :: deriv

contains

  function get_buffer_address() result(p) bind(c, name="get_buffer_address")
    type(c_ptr) :: p
    p = c_loc(buffer)
  end function get_buffer_address

  function get_buffer_capacity() result(n) bind(c, name="get_buffer_capacity")
    integer(c_int) :: n
    n = BUF_DOUBLES
  end function get_buffer_capacity

  subroutine set_model(m) bind(c, name="set_model")
    integer(c_int), value :: m
    model_id = m
  end subroutine set_model

  subroutine set_param(idx, val) bind(c, name="set_param")
    integer(c_int), value :: idx
    real(c_double), value :: val
    if (idx >= 0 .and. idx < N_PARS) then
      pars(idx + 1) = val
    end if
  end subroutine set_param

  subroutine set_dt(h) bind(c, name="set_dt")
    real(c_double), value :: h
    par_dt = h
  end subroutine set_dt

  subroutine reset_state(x0, y0, z0) bind(c, name="reset_state")
    real(c_double), value :: x0, y0, z0
    sx = x0
    sy = y0
    sz = z0
  end subroutine reset_state

  subroutine integrate(n_steps) bind(c, name="integrate")
    integer(c_int), value :: n_steps
    real(c_double) :: k1x, k1y, k1z
    real(c_double) :: k2x, k2y, k2z
    real(c_double) :: k3x, k3y, k3z
    real(c_double) :: k4x, k4y, k4z
    real(c_double) :: h, half, sixth
    integer :: i, base

    if (n_steps <= 0) return
    if (3 * n_steps > BUF_DOUBLES) return

    h     = par_dt
    half  = 0.5_c_double * h
    sixth = h / 6.0_c_double

    do i = 0, n_steps - 1
      call deriv(sx,            sy,            sz,            k1x, k1y, k1z)
      call deriv(sx + half*k1x, sy + half*k1y, sz + half*k1z, k2x, k2y, k2z)
      call deriv(sx + half*k2x, sy + half*k2y, sz + half*k2z, k3x, k3y, k3z)
      call deriv(sx + h*k3x,    sy + h*k3y,    sz + h*k3z,    k4x, k4y, k4z)

      sx = sx + sixth * (k1x + 2.0_c_double*k2x + 2.0_c_double*k3x + k4x)
      sy = sy + sixth * (k1y + 2.0_c_double*k2y + 2.0_c_double*k3y + k4y)
      sz = sz + sixth * (k1z + 2.0_c_double*k2z + 2.0_c_double*k3z + k4z)

      base = 3*i + 1
      buffer(base)     = sx
      buffer(base + 1) = sy
      buffer(base + 2) = sz
    end do
  end subroutine integrate

  subroutine deriv(x, y, z, dx, dy, dz)
    real(c_double), intent(in)  :: x, y, z
    real(c_double), intent(out) :: dx, dy, dz
    real(c_double) :: a, b, c, d, e, f

    select case (model_id)

    case (0)  ! Lorenz-63
      dx = pars(1) * (y - x)
      dy = x * (pars(2) - z) - y
      dz = x * y - pars(3) * z

    case (1)  ! Aizawa
      a = pars(1); b = pars(2); c = pars(3)
      d = pars(4); e = pars(5); f = pars(6)
      dx = (z - b) * x - d * y
      dy = d * x + (z - b) * y
      dz = c + a*z - z*z*z / 3.0_c_double &
           - (x*x + y*y) * (1.0_c_double + e*z) &
           + f * z * x*x*x

    case (2)  ! Thomas
      b = pars(1)
      dx = sin(y) - b * x
      dy = sin(z) - b * y
      dz = sin(x) - b * z

    case (3)  ! Halvorsen
      a = pars(1)
      dx = -a*x - 4.0_c_double*y - 4.0_c_double*z - y*y
      dy = -a*y - 4.0_c_double*z - 4.0_c_double*x - z*z
      dz = -a*z - 4.0_c_double*x - 4.0_c_double*y - x*x

    case default
      dx = 0.0_c_double
      dy = 0.0_c_double
      dz = 0.0_c_double

    end select
  end subroutine deriv

end module attractor_core
