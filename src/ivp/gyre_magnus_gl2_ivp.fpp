! Module   : gyre_magnus_gl2_ivp
! Purpose  : solve initial-value problems (2nd-order Gauss-Legendre Magnus)
!
! Copyright 2013 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

module gyre_magnus_gl2_ivp

  ! Uses

  use core_kinds
  use gyre_constants

  use gyre_jacobian
  use gyre_magnus_ivp

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends (magnus_ivp_t) :: magnus_gl2_ivp_t
     private
     class(jacobian_t), allocatable :: jc
   contains
     private
     procedure, public :: eval_dOmega => eval_dOmega_
     procedure, public :: abscissa => abscissa_
  end type magnus_gl2_ivp_t

  ! Interfaces

  interface magnus_gl2_ivp_t
     module procedure magnus_gl2_ivp_t_
  end interface magnus_gl2_ivp_t

  ! Access specifiers

  private

  public :: magnus_gl2_ivp_t

  ! Procedures

contains

  function magnus_gl2_ivp_t_ (jc) result (iv)

    class(jacobian_t), intent(in) :: jc
    type(magnus_gl2_ivp_t)        :: iv

    ! Construct the magnus_gl2_ivp_t

    allocate(iv%jc, SOURCE=jc)

    iv%n_e = jc%n_e

    ! Finish

    return
    
  end function magnus_gl2_ivp_t_

!****

  subroutine eval_dOmega_ (this, omega, x_a, x_b, dOmega)

    class(magnus_gl2_ivp_t), intent(in) :: this
    complex(WP), intent(in)             :: omega
    real(WP), intent(in)                :: x_a
    real(WP), intent(in)                :: x_b
    complex(WP), intent(out)            :: dOmega(:,:)

    real(WP)    :: dx
    real(WP)    :: x(1)
    complex(WP) :: A(this%n_e,this%n_e)

    $CHECK_BOUNDS(SIZE(dOmega, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(dOmega, 2),this%n_e)

    ! Evaluate the Magnus slope matrix

    ! Calculate the Jacobian

    dx = x_b - x_a
    x = this%abscissa(x_a, x_b)

    call this%jc%eval(x(1), omega, A)

    ! Set up the slope matrix

    dOmega = A

    ! Finish

    return

  end subroutine eval_dOmega_

!****

  function abscissa_ (this, x_a, x_b) result (x)

    class(magnus_gl2_ivp_t), intent(in) :: this
    real(WP), intent(in)                :: x_a
    real(WP), intent(in)                :: x_b
    real(WP), allocatable               :: x(:)

    real(WP) :: dx

    ! Set up the abscissa

    dx = x_b - x_a

    x = x_a + [0.5_WP]*dx

    ! Finish

    return
    
  end function abscissa_

end module gyre_magnus_gl2_ivp