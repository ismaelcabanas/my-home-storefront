import "reflect-metadata";

import { NextRequest, NextResponse } from "next/server";

import { ShoppingItemLister } from "../../../../contexts/inventory/inventory-items/application/shopping-list/ShoppingItemLister";
import { InvalidCursorError } from "../../../../contexts/inventory/inventory-items/domain/InvalidCursorError";
import { container } from "../../../../contexts/shared/infrastructure/dependency-injection/diod.config";
import { HttpNextResponse } from "../../../../contexts/shared/infrastructure/http/HttpNextResponse";

const lister = container.get(ShoppingItemLister);

export async function GET(request: NextRequest): Promise<NextResponse> {
	try {
		const searchParams = request.nextUrl.searchParams;
		const limitParam = searchParams.get("limit");
		const cursor = searchParams.get("cursor");

		// Input Validation: Validate limit, default to 20 if missing or invalid
		let limit: number;
		if (limitParam === null || limitParam === "") {
			limit = 20;
		} else {
			const parsed = Number.parseInt(limitParam, 10);
			limit = Number.isNaN(parsed) ? 20 : parsed;
		}

		// Business Logic: Call ShoppingItemLister.listAll
		// Cursor validation handled by service layer
		const paginatedItems = await lister.listAll(limit, cursor);

		// Return Value: HttpNextResponse.ok with 200 status
		return HttpNextResponse.ok(paginatedItems);
	} catch (error) {
		// Handle InvalidCursorError: return 400 Bad Request
		if (error instanceof InvalidCursorError) {
			return HttpNextResponse.badRequest("Invalid cursor provided");
		}

		// Handle unexpected errors: propagate to global error handler
		throw error;
	}
}
