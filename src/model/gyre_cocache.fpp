! Module   : gyre_cocache
! Purpose  : coefficients cache
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

module gyre_cocache

  ! Uses

  use core_kinds
  use core_parallel
  use core_order

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: cocache_t
     private
     real(WP), allocatable :: x(:)
     real(WP), allocatable :: c(:,:)
     integer               :: n
     integer               :: n_c
   contains
     private
     $if ($GFORTRAN_PR57922)
     procedure, public :: final => final_
     $endif
     procedure, public :: lookup => lookup_
  end type cocache_t

  ! Interfaces

  interface cocache_t
     module procedure cocache_t_
  end interface cocache_t

  $if ($MPI)
  interface bcast
     module procedure bcast_
  end interface bcast
  $endif

  ! Access specifiers

  private

  public :: cocache_t
  $if ($MPI)
  public :: bcast
  $endif

contains

  function cocache_t_ (x, c) result (cc)

    real(WP), intent(in) :: x(:)
    real(WP), intent(in) :: c(:,:)
    type(cocache_t)      :: cc

    integer, allocatable :: i(:)

    $CHECK_BOUNDS(SIZE(c, 2),SIZE(x))

    ! Construct the cocache_t

    i = unique_indices(x)

    cc%x = x(i)
    cc%c = c(:,i)

    cc%n = SIZE(i)
    cc%n_c = SIZE(c, 1)

    ! Finish

    return

  end function cocache_t_

!****

  $if ($GFORTRAN_PR57922)

  subroutine final_ (this)

    class(cocache_t), intent(inout) :: this

    ! Finalize the cocache_t

    if(ALLOCATED(this%x)) deallocate(this%x)
    if(ALLOCATED(this%c)) deallocate(this%c)

    ! Finish

    return

  end subroutine final_

  $endif

!****

  $if ($MPI)

  subroutine bcast_ (this, root_rank)

    class(cocache_t), intent(inout) :: this
    integer, intent(in)             :: root_rank

    ! Broadcast the cocache_t

    call bcast_alloc(this%x, root_rank)
    call bcast_alloc(this%c, root_rank)

    call bcast(this%n, root_rank)
    call bcast(this%n_c, root_rank)

    ! Finish

    return

  end subroutine bcast_

  $endif

!****

  function lookup_ (this, j, x) result (c)

    class(cocache_t), intent(in) :: this
    integer, intent(in)          :: j
    real(WP), intent(in)         :: x
    real(WP)                     :: c

    integer :: k

    $ASSERT(j >= 1,Invalid index)
    $ASSERT(j <= this%n_c,Invalid index)

    ! Find where x falls in the cache

    call locate_(this%x, x, k)

    ! Lookup the coeff

    c = this%c(j,k)

    ! Finish

    return

  contains

    subroutine locate_ (x, x_loc, i_loc)

      real(WP), intent(in) :: x(:)
      real(WP), intent(in) :: x_loc
      integer, intent(out) :: i_loc

      integer       :: n
      integer, save :: i_lo
      integer, save :: i_hi
      integer       :: di
      integer       :: i_mid

      !$OMP THREADPRIVATE (i_lo, i_hi)

      ! Use a binary search to find where x_loc falls in x (assumed to
      ! be in ascending order); x(i_loc) == x_loc

      n = SIZE(x)

      if(x_loc == x(n)) then

         i_loc = n

      elseif(x_loc == x(1)) then

         i_loc = 1

      else

         if(i_lo < 1 .OR. i_lo >= n) then

            i_lo = 0
            i_hi = n+1

         else

            di = 1

            if(x_loc >= x(i_lo)) then

               search_up_loop : do

                  i_hi = i_lo + di

                  if(i_hi > n) then
                     i_hi = n + 1
                     exit search_up_loop
                  endif

                  if(x_loc < x(i_hi)) exit search_up_loop

                  i_lo = i_hi
                  di = 2*di

               end do search_up_loop

            else

               search_down_loop : do

                  i_hi = i_lo
                  i_lo = i_hi - di

                  if(i_lo < 1) then
                     i_lo = 0
                     exit search_down_loop
                  endif

                  if(x_loc >= x(i_lo)) exit search_down_loop

               end do search_down_loop

            endif

         endif

         refine_loop : do

            if(i_hi-i_lo <= 1) exit refine_loop

            i_mid = (i_hi + i_lo)/2

            if(x_loc >= x(i_mid)) then
               i_lo = i_mid
            else
               i_hi = i_mid
            endif

         end do refine_loop

         i_loc = i_lo

      endif

      $ASSERT(x(i_loc) == x_loc,Value not found in cache)

      ! Finish

      return

    end subroutine locate_

  end function lookup_

end module gyre_cocache