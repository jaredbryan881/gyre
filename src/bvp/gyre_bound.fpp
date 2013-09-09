! Module   : gyre_bound
! Purpose  : boundary conditions (interface)
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

module gyre_bound

  ! Uses

  use core_kinds

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, abstract :: bound_t
     private
     integer, public :: n_e
     integer, public :: n_i
     integer, public :: n_o
   contains
     private
     procedure(init_i), deferred, public        :: init
     procedure(inner_bound_i), deferred, public :: inner_bound
     procedure(outer_bound_i), deferred, public :: outer_bound
  end type bound_t

  ! Interfaces

  abstract interface

     subroutine init_i (this, cf, jc, op)
       use core_kinds
       use gyre_coeffs
       use gyre_jacobian
       use gyre_oscpar
       import bound_t
       class(bound_t), intent(out)           :: this
       class(coeffs_t), intent(in), target   :: cf
       class(jacobian_t), intent(in), target :: jc
       type(oscpar_t), intent(in), target    :: op
     end subroutine init_i

     function inner_bound_i (this, x_i, omega) result (B_i)
       use core_kinds
       import bound_t
       class(bound_t), intent(in) :: this
       real(WP), intent(in)       :: x_i
       complex(WP), intent(in)    :: omega
       complex(WP)                :: B_i(this%n_i,this%n_e)
     end function inner_bound_i

     function outer_bound_i (this, x_o, omega) result (B_o)
       use core_kinds
       import bound_t
       class(bound_t), intent(in) :: this
       real(WP), intent(in)       :: x_o
       complex(WP), intent(in)    :: omega
       complex(WP)                :: B_o(this%n_o,this%n_e)
     end function outer_bound_i

  end interface

  ! Access specifiers

  private

  public :: bound_t

end module gyre_bound
