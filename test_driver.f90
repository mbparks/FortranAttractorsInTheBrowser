! test_driver.f90
!
! Native test harness for attractor_core. Runs each of the four models
! through a short integration and checks that the trajectory stays finite
! and within sane bounds. Compiled with gfortran and run as a normal
! executable; produces a one-line PASS/FAIL per model plus a final summary.

program test_driver
  use, intrinsic :: iso_c_binding
  use attractor_core
  use attractor_state, only: buffer
  implicit none

  integer :: total, passed

  total  = 0
  passed = 0

  call check_lorenz(total, passed)
  call check_aizawa(total, passed)
  call check_thomas(total, passed)
  call check_halvorsen(total, passed)

  write(*,'(A,I0,A,I0,A)') ">>> ", passed, " / ", total, " model checks passed"
  if (passed /= total) stop 1

contains

  subroutine check_lorenz(total, passed)
    integer, intent(inout) :: total, passed
    integer, parameter :: N = 400
    real(c_double) :: x, y, z
    real(c_double) :: xmin, xmax, ymin, ymax, zmin, zmax
    logical :: finite, bounded

    call set_model(0_c_int)
    call set_param(0_c_int, 10.0_c_double)
    call set_param(1_c_int, 28.0_c_double)
    call set_param(2_c_int, 8.0_c_double / 3.0_c_double)
    call set_dt(0.005_c_double)
    call reset_state(0.1_c_double, 0.0_c_double, 0.0_c_double)
    call integrate(int(N, c_int))

    call buffer_stats(N, finite, xmin, xmax, ymin, ymax, zmin, zmax)
    bounded = finite .and. xmin > -40.0_c_double .and. xmax < 40.0_c_double &
                       .and. ymin > -40.0_c_double .and. ymax < 40.0_c_double &
                       .and. zmin > -10.0_c_double .and. zmax < 60.0_c_double
    x = buffer(3*N - 2); y = buffer(3*N - 1); z = buffer(3*N)
    total = total + 1
    if (bounded) then
      passed = passed + 1
      write(*,'(A,3F10.4,A,2F8.2,A,2F8.2,A)') &
        "PASS  lorenz    end=(", x, y, z, ")  x[", xmin, xmax, "]  z[", zmin, zmax, "]"
    else
      write(*,'(A,L1,A)') "FAIL  lorenz    finite=", finite, ", bounds violated"
    end if
  end subroutine check_lorenz

  subroutine check_aizawa(total, passed)
    integer, intent(inout) :: total, passed
    integer, parameter :: N = 400
    real(c_double) :: x, y, z
    real(c_double) :: xmin, xmax, ymin, ymax, zmin, zmax
    logical :: finite, bounded

    call set_model(1_c_int)
    call set_param(0_c_int, 0.95_c_double)   ! a
    call set_param(1_c_int, 0.70_c_double)   ! b
    call set_param(2_c_int, 0.60_c_double)   ! c
    call set_param(3_c_int, 3.50_c_double)   ! d
    call set_param(4_c_int, 0.25_c_double)   ! e
    call set_param(5_c_int, 0.10_c_double)   ! f
    call set_dt(0.010_c_double)
    call reset_state(0.1_c_double, 0.0_c_double, 0.0_c_double)
    call integrate(int(N, c_int))

    call buffer_stats(N, finite, xmin, xmax, ymin, ymax, zmin, zmax)
    bounded = finite .and. abs(xmin) < 5.0_c_double .and. abs(xmax) < 5.0_c_double &
                       .and. abs(ymin) < 5.0_c_double .and. abs(ymax) < 5.0_c_double &
                       .and. abs(zmin) < 5.0_c_double .and. abs(zmax) < 5.0_c_double
    x = buffer(3*N - 2); y = buffer(3*N - 1); z = buffer(3*N)
    total = total + 1
    if (bounded) then
      passed = passed + 1
      write(*,'(A,3F10.4,A,2F8.2,A,2F8.2,A)') &
        "PASS  aizawa    end=(", x, y, z, ")  x[", xmin, xmax, "]  z[", zmin, zmax, "]"
    else
      write(*,'(A,L1,A)') "FAIL  aizawa    finite=", finite, ", bounds violated"
    end if
  end subroutine check_aizawa

  subroutine check_thomas(total, passed)
    integer, intent(inout) :: total, passed
    integer, parameter :: N = 400
    real(c_double) :: x, y, z
    real(c_double) :: xmin, xmax, ymin, ymax, zmin, zmax
    logical :: finite, bounded

    call set_model(2_c_int)
    call set_param(0_c_int, 0.19_c_double)   ! b
    call set_dt(0.05_c_double)
    call reset_state(1.1_c_double, 1.1_c_double, -0.01_c_double)
    call integrate(int(N, c_int))

    call buffer_stats(N, finite, xmin, xmax, ymin, ymax, zmin, zmax)
    ! Thomas with b near chaos lives roughly within +-8
    bounded = finite .and. abs(xmin) < 12.0_c_double .and. abs(xmax) < 12.0_c_double &
                       .and. abs(ymin) < 12.0_c_double .and. abs(ymax) < 12.0_c_double &
                       .and. abs(zmin) < 12.0_c_double .and. abs(zmax) < 12.0_c_double
    x = buffer(3*N - 2); y = buffer(3*N - 1); z = buffer(3*N)
    total = total + 1
    if (bounded) then
      passed = passed + 1
      write(*,'(A,3F10.4,A,2F8.2,A,2F8.2,A)') &
        "PASS  thomas    end=(", x, y, z, ")  x[", xmin, xmax, "]  z[", zmin, zmax, "]"
    else
      write(*,'(A,L1,A)') "FAIL  thomas    finite=", finite, ", bounds violated"
    end if
  end subroutine check_thomas

  subroutine check_halvorsen(total, passed)
    integer, intent(inout) :: total, passed
    integer, parameter :: N = 400
    real(c_double) :: x, y, z
    real(c_double) :: xmin, xmax, ymin, ymax, zmin, zmax
    logical :: finite, bounded

    call set_model(3_c_int)
    call set_param(0_c_int, 1.89_c_double)   ! a
    call set_dt(0.005_c_double)
    call reset_state(-1.48_c_double, -1.51_c_double, 2.04_c_double)
    call integrate(int(N, c_int))

    call buffer_stats(N, finite, xmin, xmax, ymin, ymax, zmin, zmax)
    bounded = finite .and. abs(xmin) < 15.0_c_double .and. abs(xmax) < 15.0_c_double &
                       .and. abs(ymin) < 15.0_c_double .and. abs(ymax) < 15.0_c_double &
                       .and. abs(zmin) < 15.0_c_double .and. abs(zmax) < 15.0_c_double
    x = buffer(3*N - 2); y = buffer(3*N - 1); z = buffer(3*N)
    total = total + 1
    if (bounded) then
      passed = passed + 1
      write(*,'(A,3F10.4,A,2F8.2,A,2F8.2,A)') &
        "PASS  halvorsen end=(", x, y, z, ")  x[", xmin, xmax, "]  z[", zmin, zmax, "]"
    else
      write(*,'(A,L1,A)') "FAIL  halvorsen finite=", finite, ", bounds violated"
    end if
  end subroutine check_halvorsen

  subroutine buffer_stats(n_points, finite, xmin, xmax, ymin, ymax, zmin, zmax)
    use ieee_arithmetic, only: ieee_is_finite
    integer, intent(in)         :: n_points
    logical, intent(out)        :: finite
    real(c_double), intent(out) :: xmin, xmax, ymin, ymax, zmin, zmax
    integer :: i, base
    real(c_double) :: x, y, z

    xmin =  huge(0.0_c_double); xmax = -huge(0.0_c_double)
    ymin =  huge(0.0_c_double); ymax = -huge(0.0_c_double)
    zmin =  huge(0.0_c_double); zmax = -huge(0.0_c_double)
    finite = .true.

    do i = 1, n_points
      base = 3*(i - 1) + 1
      x = buffer(base)
      y = buffer(base + 1)
      z = buffer(base + 2)
      if (.not. ieee_is_finite(x) .or. .not. ieee_is_finite(y) .or. .not. ieee_is_finite(z)) then
        finite = .false.
        return
      end if
      if (x < xmin) xmin = x;  if (x > xmax) xmax = x
      if (y < ymin) ymin = y;  if (y > ymax) ymax = y
      if (z < zmin) zmin = z;  if (z > zmax) zmax = z
    end do
  end subroutine buffer_stats

end program test_driver
