# Fudz Hub dashboard API alignment

This backend update accompanies the refreshed restaurant dashboard. It does not include database data or environment secrets.

## API changes

- Restaurant owners can retrieve/update their own restaurant profile even when it is not publicly approved/listed; backend-controlled approval/rating/aggregate fields are read-only.
- Order access/update is constrained to the owning restaurant and active restaurant staff; accept returns the serialized updated order. Order status/search/ordering filters are enabled.
- Delivery requests support restaurant-owner/staff scoping, courier assignment/completion, available-courier lookup, and status/search filters.
- Promotion writes require owner/admin access, owner-created promotions are forced to the owner's restaurant, and the list supports search.
- Review listing supports restaurant, rating and text filters; owners and active staff can reply only to reviews for their restaurant.
- Staff serializer responses include email/name display fields; owner-scoped creation no longer needs a client-supplied restaurant ID. Deactivation/removal disables the associated login account.
- Account profile includes editable first/last name and phone fields; staff profile responses now return valid staff/restaurant IDs and active state.

## Deployment

1. Deploy the API source with the same environment configuration and dependencies as the existing service.
2. Run `python manage.py migrate` to apply `reviews.0002_restaurantreview_response`.
3. Run `python manage.py check` and the project's test suite in the deployment environment.
4. Deploy the frontend package with the API base URL already configured for the environment.

The review migration adds nullable/blank `response` text and nullable `responded_at` time fields. The rest of the changes are serializer/view/permission/filter updates and require no schema migration.

## Validation note

All touched backend Python modules compile. Django checks were not available in the authoring sandbox because Django is not installed there; run the checks above in the backend environment before deployment.
