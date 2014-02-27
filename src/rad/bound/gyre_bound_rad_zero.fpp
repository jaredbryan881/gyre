! Module   : gyre_bound_rad_zero
! Purpose  : radial adiabatic boundary conditions (zero)
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

module gyre_bound_rad_zero

  ! Uses

  use core_kinds

  use gyre_bound
  use gyre_jacobian
  use gyre_model
  use gyre_oscpar

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends (bound_t) :: bound_rad_zero_t
     private
     class(model_t), pointer        :: ml => null()
     class(jacobian_t), allocatable :: jc
     type(oscpar_t)                 :: op
   contains 
     private
     procedure, public :: inner_bound => inner_bound_
     procedure, public :: outer_bound => outer_bound_
  end type bound_rad_zero_t
  
  ! Interfaces

  interface bound_rad_zero_t
     module procedure bound_rad_zero_t_
  end interface bound_rad_zero_t
  
  ! Access specifiers

  private

  public :: bound_rad_zero_t

  ! Procedures

contains

  function bound_rad_zero_t_ (ml, jc, op) result (bd)

    class(model_t), pointer, intent(in) :: ml
    class(jacobian_t), intent(in)       :: jc
    type(oscpar_t), intent(in)          :: op
    type(bound_rad_zero_t)              :: bd

    ! Construct the bound_rad_zero_t

    bd%ml => ml
    allocate(bd%jc, SOURCE=jc)
    bd%op = op

    bd%n_i = 1
    bd%n_o = 1
    bd%n_e = bd%n_i + bd%n_o

    $CHECK_BOUNDS(bd%n_e,bd%jc%n_e)

    ! Finish

    return
    
  end function bound_rad_zero_t_

!****

  function inner_bound_ (this, x_i, omega) result (B_i)

    class(bound_rad_zero_t), intent(in) :: this
    real(WP), intent(in)                :: x_i
    complex(WP), intent(in)             :: omega
    $if ($GFORTRAN_PR_58007)
    complex(WP), allocatable            :: B_i(:,:)
    $else
    complex(WP)                         :: B_i(this%n_i,this%n_e)
    $endif

    $ASSERT(x_i == 0._WP,Boundary condition invalid for x_i /= 0)

    $if ($GFORTRAN_PR_58007)
    allocate(B_i(this%n_i,this%n_e))
    $endif

    ! Set the inner boundary conditions to enforce non-diverging modes

    associate(c_1 => this%ml%c_1(x_i), &
              omega_c => this%ml%omega_c(x_i, this%op%m, omega))

      B_i(1,1) = c_1*omega_c**2
      B_i(1,2) = 0._WP

    end associate

    B_i = MATMUL(B_i, this%jc%trans_matrix(x_i, omega, .TRUE.))

    ! Finish

    return

  end function inner_bound_
  
!****

  function outer_bound_ (this, x_o, omega) result (B_o)

    class(bound_rad_zero_t), intent(in) :: this
    real(WP), intent(in)                :: x_o
    complex(WP), intent(in)             :: omega
    $if ($GFORTRAN_PR_58007)
    complex(WP), allocatable            :: B_o(:,:)
    $else
    complex(WP)                         :: B_o(this%n_o,this%n_e)
    $endif

    $if ($GFORTRAN_PR_58007)
    allocate(B_o(this%n_o,this%n_e))
    $endif

    ! Set the outer boundary conditions

    B_o(1,1) = 1._WP
    B_o(1,2) = -1._WP

    B_o = MATMUL(B_o, this%jc%trans_matrix(x_o, omega, .TRUE.))

    ! Finish

    return

  end function outer_bound_

end module gyre_bound_rad_zero
