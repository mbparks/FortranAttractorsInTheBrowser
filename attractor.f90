! attractor.f90
!
! Lorenz-63 strange attractor, integrated by classical RK4.
! Compiled to wasm32 via LFortran for execution in a browser.
!
! Exposed C-bound entry points:
!   get_buffer_address  -> c_ptr : linear-memory pointer to the output buffer
!   get_buffer_capacity -> i32   : number of doubles in the buffer
!   set_params(sigma, rho, beta, dt) : update Lorenz parameters
!   reset_state(x0, y0, z0)          : reset trajectory to a seed point
!   integrate(n_steps)               : advance n_steps and fill the buffer
!
! Buffer layout: contiguous [x0, y0, z0, x1, y1, z1, ...] as IEEE 754 doubles.
! After integrate(n), the JS side reads 3*n doubles starting at the buffer base.

module attractor_state
  use, intrinsic :: iso_c_binding
  implicit none

  integer, parameter :: BUF_DOUBLES = 30000  ! up to 10,000 points per call

  real(c_double), target, save :: buffer(BUF_DOUBLES)

  real(c_double), save :: sx = 0.1_c_double
  real(c_double), save :: sy = 0.0_c_double
  real(c_double), save :: sz = 0.0_c_double

  real(c_double), save :: par_sigma = 10.0_c_double
  real(c_double), save :: par_rho   = 28.0_c_double
  real(c_double), save :: par_beta  = 2.6666666666666667_c_double
  real(c_double), save :: par_dt    = 0.005_c_double
end module attractor_state


program attractor
  use, intrinsic :: iso_c_binding
  use attractor_state
  implicit none
  ! No main-program body. With wasm-ld --no-entry, the exported
  ! C-bound procedures below are called directly from JS.
contains

  function get_buffer_address() result(p) bind(c, name="get_buffer_address")
    type(c_ptr) :: p
    p = c_loc(buffer)
  end function get_buffer_address

  function get_buffer_capacity() result(n) bind(c, name="get_buffer_capacity")
    integer(c_int) :: n
    n = BUF_DOUBLES
  end function get_buffer_capacity

  subroutine set_params(s, r, b, h) bind(c, name="set_params")
    real(c_double), value :: s, r, b, h
    par_sigma = s
    par_rho   = r
    par_beta  = b
    par_dt    = h
  end subroutine set_params

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
    dx = par_sigma * (y - x)
    dy = x * (par_rho - z) - y
    dz = x * y - par_beta * z
  end subroutine deriv

end program attractor
