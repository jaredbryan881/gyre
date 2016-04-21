! Incfile  : gyre_ad_diff
! Purpose  : adiabatic difference equations
!
! Copyright 2015-2016 Rich Townsend
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

module gyre_ad_diff

  ! Uses

  use core_kinds

  use gyre_ad_eqns
  use gyre_ad_match
  use gyre_diff
  use gyre_diff_factory
  use gyre_ext
  use gyre_grid
  use gyre_model
  use gyre_mode_par
  use gyre_num_par
  use gyre_osc_par
  use gyre_point

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type, extends (r_diff_t) :: ad_diff_t
     private
     class(r_diff_t), allocatable :: df
   contains
     private
     procedure, public :: build
  end type ad_diff_t

  ! Interfaces

  interface ad_diff_t
     module procedure ad_diff_t_
  end interface ad_diff_t

  ! Access specifiers

  private

  public :: ad_diff_t

  ! Procedures

contains

  function ad_diff_t_ (ml, gr, k, md_p, nm_p, os_p) result (df)

    class(model_t), pointer, intent(in) :: ml
    type(grid_t), intent(in)            :: gr
    integer, intent(in)                 :: k
    type(mode_par_t), intent(in)        :: md_p
    type(num_par_t), intent(in)         :: nm_p
    type(osc_par_t), intent(in)         :: os_p
    type(ad_diff_t)                     :: df

    type(ad_eqns_t) :: eq

    $ASSERT_DEBUG(k >= 1,Invalid index)
    $ASSERT_DEBUG(k < gr%n_k,Invalid index)

    ! Construct the ad_diff_t

    if (gr%pt(k+1)%s == gr%pt(k)%s) then

       eq = ad_eqns_t(ml, gr, md_p, os_p)
       
       allocate(df%df, SOURCE=r_diff_t(eq, gr%pt(k), gr%pt(k+1), nm_p))

    else

       allocate(df%df, SOURCE=ad_match_t(ml, gr, k, md_p, os_p))

    endif

    df%n_e = df%df%n_e

    ! Finish

    return

  end function ad_diff_t_

  !****

  subroutine build (this, omega, E_l, E_r, scl)

    class(ad_diff_t), intent(in) :: this
    real(WP), intent(in)         :: omega
    real(WP), intent(out)        :: E_l(:,:)
    real(WP), intent(out)        :: E_r(:,:)
    type(r_ext_t), intent(out)   :: scl

    $CHECK_BOUNDS(SIZE(E_l, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(E_l, 2),this%n_e)

    $CHECK_BOUNDS(SIZE(E_r, 1),this%n_e)
    $CHECK_BOUNDS(SIZE(E_r, 2),this%n_e)

    ! Build the difference equations

    call this%df%build(omega, E_l, E_r, scl)

    ! Finish

    return

  end subroutine build

end module gyre_ad_diff