import "reflect-metadata";

import { NextRequest, NextResponse } from "next/server";

import { ProductByIdSearcher } from "../../../../contexts/pantry/products/application/search-by-id/ProductByIdSearcher";
import { ProductStockUpdater } from "../../../../contexts/pantry/products/application/update-stock/ProductStockUpdater";
import { container } from "../../../../contexts/shared/infrastructure/dependency-injection/diod.config";
import { HttpNextResponse } from "../../../../contexts/shared/infrastructure/http/HttpNextResponse";

const byIdSearcher = container.get(ProductByIdSearcher);
const stockUpdater = container.get(ProductStockUpdater);

export async function GET(
	_request: NextRequest,
	{ params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
	const { id } = await params;
	const product = await byIdSearcher.search(id);

	if (!product) {
		return HttpNextResponse.notFound();
	}

	return HttpNextResponse.ok(product);
}

export async function PATCH(
	request: NextRequest,
	{ params }: { params: Promise<{ id: string }> },
): Promise<NextResponse> {
	try {
		const { id } = await params;
		const body = await request.json();
		const { currentStock } = body;

		await stockUpdater.update(id, currentStock);

		const updated = await byIdSearcher.search(id);

		return HttpNextResponse.ok(updated);
	} catch (error) {
		if (error instanceof Error && error.message === "INVALID_STOCK_LEVEL") {
			return NextResponse.json(
				{
					error: {
						type: error.message,
						params:
							(
								error as unknown as {
									params?: Record<string, unknown>;
								}
							).params ?? {},
					},
				},
				{ status: 400 },
			);
		}
		if (error instanceof Error && error.message === "PRODUCT_NOT_FOUND") {
			return HttpNextResponse.notFound();
		}

		return HttpNextResponse.internalServerError();
	}
}
